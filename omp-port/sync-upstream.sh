#!/usr/bin/env bash
# Build the omp port of pstack from an upstream cursor/plugins commit. Port-only file, never upstream.
#
# The port is a build, not a maintained tree. plugins/pstack/{skills,agents} is upstream text at
# the pinned sha with omp-port/rules.sed applied, omp-port/patches/*.patch applied on top, and the
# paths in omp-port/owned.txt carried across. Upstream prose can therefore never conflict with
# port prose, because the port never edits upstream files in place.
#
# Usage
#   bash omp-port/sync-upstream.sh check
#       Lists upstream commits touching pstack/ since the pin, newest first, one per line as
#       "<short-sha>\t<date>\t<subject>". Empty stdout and exit 0 mean no drift. The resolved
#       target head sha is written to stderr as "target <full-sha>", and also to the file named
#       by SYNC_TARGET_OUT when that variable is set, which is how CI captures it.
#   bash omp-port/sync-upstream.sh [<target-sha>]
#       Moves the pin to <target-sha> and increments the port patch version once. <target-sha>
#       must be a full 40-hex sha that touched pstack/. Default is the newest such commit. A target
#       equal to the current pin is a no-op that changes nothing, version included. Refuses to run
#       when the plugin tree carries uncommitted changes the build would destroy, owned paths
#       excepted.
#   bash omp-port/sync-upstream.sh release
#       Rebuilds at the current pin and increments the port patch version once. This is the
#       port-only release, for a change to rules.sed, patches/, owned.txt, or an owned path.
#   bash omp-port/sync-upstream.sh rebuild
#       Rebuilds at the current pin and keeps the version. Uncommitted build output is what it
#       replaces, so unlike a sync it does not refuse a dirty tree.
#   bash omp-port/sync-upstream.sh recover
#       Finishes or undoes an installation that a kill interrupted. An interrupted replacement is
#       rolled back. A finished replacement whose staging failed is staged again, at the same
#       version, without a build. Every mode that installs does this first, so the command exists
#       to do it deliberately.
#
# The port version is its own stable counter, kept in plugins/pstack/package.json. It is a plain
# MAJOR.MINOR.PATCH, written to the package, the catalog metadata, and both catalog plugin entries.
# Upstream's version is printed for provenance and feeds nothing.
#
# An install is a transaction. The tree, the package manifest, the catalog, and the pin are built
# and validated in scratch on the destination filesystem, the three live destinations are backed
# up, and only then are they replaced. A failure or a trapped signal rolls the old installation
# back, so a failed build leaves the plugin, catalog, pin, and index as they were. Replacing three
# paths is not one atomic operation, so a kill that cannot be trapped leaves its backups and a
# marker behind in the git directory, and the next invocation restores the previous installation
# before it looks at anything else. Changes are staged in git only after the replacement committed.
# If that staging fails, the committed transaction is kept, and recover stages it and removes it
# only after staging succeeds. Every mode except check runs under an exclusive lock on
# <git-dir>/pstack-port.lock, taken before recovery and held until the run exits. A second run
# fails at once without touching the first one's transaction, and the kernel drops the lock if
# the holder is killed.
#
# Exit 0 clean, 1 failure, including a patch that no longer applies.
# Override the canonical checkout location with CANON=/path.
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
. "$HERE/lib.sh"
cd "$REPO_ROOT"

PIN_FILE=omp-port/UPSTREAM
PLUGIN=plugins/pstack
CATALOG=.omp-plugin/marketplace.json
SEMVER_RE='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'
TXN=""
TXN_OWNED=""

die() { printf 'sync-upstream: %s\n' "$*" >&2; exit 1; }
note() { printf 'sync-upstream: %s\n' "$*" >&2; }

read_pin() {
	[ -f "$PIN_FILE" ] ||
		die "no pin at $PIN_FILE, create it holding the full 40-hex upstream sha this port was built from"
	local p
	p=$(tr -d '[:space:]' <"$PIN_FILE")
	[[ $p =~ ^[0-9a-f]{40}$ ]] || die "$PIN_FILE must hold one full 40-hex sha, got '$p'"
	printf '%s\n' "$p"
}

# The path-filtered history is the only history that matters here. A monorepo head that never
# touched pstack/ is not a syncable target and the next run could not find it as a pin.
pstack_log() {
	gh api "repos/cursor/plugins/commits?path=pstack&sha=main&per_page=100" \
		--jq '.[] | [.sha, .sha[0:7], (.commit.author.date|split("T")[0]), (.commit.message|split("\n")[0])] | @tsv'
}

upstream_head() { gh api 'repos/cursor/plugins/commits?path=pstack&sha=main&per_page=1' --jq '.[0].sha'; }

commits_since() {
	local pin="$1" log out st=0
	log=$(pstack_log)
	out=$(printf '%s\n' "$log" |
		awk -F'\t' -v pin="$pin" '$1==pin { seen=1; exit } { print $2"\t"$3"\t"$4 } END { if (!seen) exit 3 }') || st=$?
	[ "$st" -eq 0 ] ||
		die "pin $pin is not among the last 100 upstream pstack commits, widen the query in pstack_log"
	[ -z "$out" ] || printf '%s\n' "$out"
}

# ---- the version ----------------------------------------------------------------------------

valid_semver() { [[ ${1:-} =~ $SEMVER_RE ]]; }

# 0.15.23 -> 0.15.24. Only a plain MAJOR.MINOR.PATCH with no leading zero is a version here.
bump_patch() {
	valid_semver "${1:-}" || return 1
	printf '%s.%s.%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "$((BASH_REMATCH[3] + 1))"
}

# The version an install of <mode> writes, given the one on disk. rebuild reproduces and keeps it,
# release and a sync to a new pin advance the patch once.
derive_version() {
	local mode="$1" cur="$2"
	valid_semver "$cur" || return 1
	case "$mode" in
	rebuild) printf '%s\n' "$cur" ;;
	release | sync) bump_patch "$cur" ;;
	*) return 1 ;;
	esac
}

current_version() {
	local v
	[ -f "$PLUGIN/package.json" ] || die "no $PLUGIN/package.json, the port version counter lives there"
	v=$(jq -er '.version' "$PLUGIN/package.json") || die "$PLUGIN/package.json has no readable version"
	valid_semver "$v" ||
		die "$PLUGIN/package.json version '$v' is not a plain MAJOR.MINOR.PATCH without leading zeros"
	printf '%s\n' "$v"
}

# The catalog carries the counter in three places. They have to agree with the package before
# anything advances, or a half-applied release would be advanced over. fan-out's entry may still
# lack a version, which the first release initialises.
check_catalog_versions() {
	local cur="$1" meta pst fan
	[ -f "$CATALOG" ] || die "no catalog at $CATALOG"
	jq -e '(.plugins | map(.name)) as $n | ($n | index("pstack")) != null and ($n | index("fan-out")) != null' \
		"$CATALOG" >/dev/null || die "$CATALOG must list both the pstack and the fan-out plugin"
	meta=$(jq -r '.metadata.version // "missing"' "$CATALOG") || die "$CATALOG is not readable JSON"
	pst=$(jq -r '.plugins[] | select(.name == "pstack") | .version // "missing"' "$CATALOG") || die "$CATALOG is not readable JSON"
	fan=$(jq -r '.plugins[] | select(.name == "fan-out") | .version // "missing"' "$CATALOG") || die "$CATALOG is not readable JSON"
	[ "$meta" = "$cur" ] || die "$CATALOG metadata.version is $meta, the package says $cur, reconcile them first"
	[ "$pst" = "$cur" ] || die "$CATALOG pstack version is $pst, the package says $cur, reconcile them first"
	{ [ "$fan" = "$cur" ] || [ "$fan" = missing ]; } ||
		die "$CATALOG fan-out version is $fan, the package says $cur, reconcile them first"
}

# ---- the installation transaction -----------------------------------------------------------

# Put the old installation back. The state is read off what exists, so this is safe to run again
# after it was itself interrupted. bak.plugin means the live plugin directory, if there is one, is
# the new one. bak.done means the catalog and pin copies are complete and the live ones may be the
# new ones. A committed transaction is never touched here: all three paths were replaced, so the
# backups are garbage, but the record of the replacement is also the only proof that staging is
# still owed, and finish_committed_txn is the one place that removes it.
rollback_txn() {
	[ -d "$TXN" ] || return 0
	[ ! -e "$TXN/committed" ] || return 0
	if [ -e "$TXN/bak.plugin" ]; then
		rm -rf "$PLUGIN" && mv "$TXN/bak.plugin" "$PLUGIN" || return 1
	fi
	if [ -e "$TXN/bak.done" ]; then
		cp -p "$TXN/bak.catalog" "$TXN/restore.catalog" && mv -f "$TXN/restore.catalog" "$CATALOG" || return 1
		cp -p "$TXN/bak.pin" "$TXN/restore.pin" && mv -f "$TXN/restore.pin" "$PIN_FILE" || return 1
	fi
	rm -rf "$TXN"
}

stage_changes() { git add -A -- "$PLUGIN" "$CATALOG" "$PIN_FILE"; }

# Stage first and delete the record only after staging worked, so a failed stage leaves the
# committed transaction for the next recover.
finish_committed_txn() {
	stage_changes || return 1
	rm -rf "$TXN"
}

on_exit() {
	local rc=$?
	trap - EXIT
	if [ -n "$TXN_OWNED" ]; then
		if [ -e "$TXN/committed" ]; then
			note "the installation is complete but not staged, the transaction is kept at $TXN, run: bash omp-port/sync-upstream.sh recover"
			[ "$rc" -ne 0 ] || rc=1
		elif ! rollback_txn; then
			note "rollback did not finish, the transaction is kept at $TXN, run: bash omp-port/sync-upstream.sh recover"
			rc=1
		fi
	fi
	exit "$rc"
}

# Every mode that installs, recovery included, runs under one exclusive lock on a file in the git
# directory. flock is not on every host, perl is, and the kernel drops the lock when the holder
# dies, so a kill never leaves a stale lock. The lock is taken by re-running this script under
# perl, which keeps the descriptor open across the exec, and it is held through replacement,
# staging, and cleanup. A second invocation fails at once and touches nothing.
acquire_lock() {
	[ -z "${PSTACK_PORT_LOCK_HELD:-}" ] || return 0
	local lock rc=0
	lock=$(git rev-parse --absolute-git-dir)/pstack-port.lock
	PSTACK_PORT_LOCK_HELD=1 perl -MFcntl=:flock -e '
		my ($lock, @cmd) = @ARGV;
		open(my $fh, ">>", $lock) or die "cannot open $lock: $!\n";
		flock($fh, LOCK_EX | LOCK_NB) or exit 75;
		fcntl($fh, F_SETFD, 0) or die "cannot keep the lock open: $!\n";
		exec @cmd or die "cannot run @cmd: $!\n";' "$lock" bash "$HERE/sync-upstream.sh" "$@" || rc=$?
	[ "$rc" -ne 75 ] || die "another sync-upstream run holds the installation lock at $lock, wait for it to finish"
	exit "$rc"
}

# Look for a transaction a kill interrupted and settle it before anything else reads the tree.
recover_txn() {
	TXN=$(git rev-parse --absolute-git-dir)/pstack-port-txn
	if [ ! -d "$TXN" ]; then
		[ "${1:-}" != explicit ] || note "no interrupted installation to recover"
		return 0
	fi
	if [ -e "$TXN/committed" ]; then
		note "a previous run finished replacing the installation, staging the result and discarding its backups"
		finish_committed_txn || die "could not stage the finished installation, the transaction is kept at $TXN, fix the cause and run recover again"
	else
		note "a previous run was interrupted, restoring the previous installation"
		rollback_txn || die "could not restore the previous installation from $TXN, fix the cause and run recover again"
	fi
}

same_fs() {
	local a b
	a=$(stat -c %d "$1") && b=$(stat -c %d "$2") && [ "$a" = "$b" ]
}

# Everything under the plugin directory is either generated, owned, or the manifest, because the
# whole directory is replaced. Anything else would be deleted without a trace.
check_plugin_layout() {
	local e name p known
	known=" skills agents package.json .DS_Store "
	while IFS= read -r p; do
		known="$known${p%%/*} "
	done < <(owned_paths)
	for e in "$PLUGIN"/* "$PLUGIN"/.[!.]*; do
		[ -e "$e" ] || continue
		name=$(basename "$e")
		case "$known" in *" $name "*) ;; *) die "$e is neither generated nor owned, move it or list it in omp-port/owned.txt before installing" ;; esac
	done
}

# Build <sha> into a complete, validated candidate installation and swap it in. <next> is the
# port version to write. The pin file takes <sha> only when <move-pin> is yes.
do_build() {
	local sha="$1" pin="$2" next="$3" move="$4" cur work n p k a up desc untiered newpin changed
	cur=$(current_version)
	check_catalog_versions "$cur"
	ensure_canon "$sha" || die "no canonical checkout at $CANON and cloning $UPSTREAM_URL failed"
	check_plugin_layout
	TXN=$(git rev-parse --absolute-git-dir)/pstack-port-txn
	same_fs "$(dirname "$TXN")" "$PLUGIN" && same_fs "$PLUGIN" "$(dirname "$CATALOG")" && same_fs "$PLUGIN" "$(dirname "$PIN_FILE")" ||
		die "the git directory, the plugin, the catalog, and the pin are not on one filesystem, the replacement could not be a rename"

	trap on_exit EXIT
	trap 'exit 130' INT
	trap 'exit 143' TERM
	trap 'exit 129' HUP
	mkdir "$TXN" || die "a transaction is already in progress at $TXN, run: bash omp-port/sync-upstream.sh recover"
	TXN_OWNED=1
	work="$TXN/new"
	mkdir "$work" || die "cannot create $work"

	build_tree "$sha" "$work" || die "build at ${sha:0:7} failed, see the output above"
	prepare_tree "$work" || die "preparing the owned paths failed, the installation is unchanged"
	[ -d "$work/skills" ] && [ -d "$work/agents" ] || die "the build produced no skills or agents directory"

	# The manifest is carried across and only its version moves.
	jq --indent 2 --arg v "$next" '.version = $v' "$PLUGIN/package.json" >"$work/package.json" ||
		die "writing the package manifest failed, the installation is unchanged"
	chmod --reference="$PLUGIN/package.json" "$work/package.json"
	jq -e --arg v "$next" '.version == $v and ((.omp.extensions // []) | length) > 0' "$work/package.json" >/dev/null ||
		die "the prepared package manifest lost its version or its extension declaration"
	while IFS= read -r p; do
		[ -f "$work/$p" ] || die "the prepared package declares $p, which the prepared tree lacks"
	done < <(jq -r '.omp.extensions[]' "$work/package.json" | sed 's|^\./||')

	read -r n p k < <(port_counts "$work")
	[ -n "${k:-}" ] || die "counting the prepared tree failed, the installation is unchanged"
	a=$(find "$work/agents" -maxdepth 1 -type f -name '*.md' | wc -l | tr -d ' ')
	desc="$n skills, $p playbooks, $k principles, the poteto-mode pin, and $a agents. Upstream cursor/plugins pstack at ${sha:0:7}."
	jq --indent 2 --arg v "$next" --arg d "$desc" '
		.metadata.version = $v
		| (.plugins[] | select(.name == "pstack")) |= (.version = $v | .description = $d)
		| (.plugins[] | select(.name == "fan-out")) |= (.version = $v)' \
		"$CATALOG" >"$TXN/new.catalog" || die "writing the catalog failed, the installation is unchanged"
	chmod --reference="$CATALOG" "$TXN/new.catalog"
	jq -e --arg v "$next" '.metadata.version == $v and ([.plugins[].version] | all(. == $v))' "$TXN/new.catalog" >/dev/null ||
		die "the prepared catalog does not carry $next in every place"

	newpin="$pin"
	[ "$move" != yes ] || newpin="$sha"
	printf '%s\n' "$newpin" >"$TXN/new.pin"
	chmod --reference="$PIN_FILE" "$TXN/new.pin"
	[[ $(tr -d '[:space:]' <"$TXN/new.pin") =~ ^[0-9a-f]{40}$ ]] || die "the prepared pin is not a full sha"

	up=$(git -C "$CANON" show "$sha:pstack/.cursor-plugin/plugin.json" 2>/dev/null | jq -r '.version // "unknown"' 2>/dev/null) || up=unknown
	# A slug the tiered rules never named still comes out model-agnostic, but it is worth a
	# tiered rule that names the right capability instead of the generic replacement.
	untiered=$(untiered_slugs "$sha") || die "the catch-all rebuild at ${sha:0:7} failed"

	# Backups first, markers second, and the markers are what recovery trusts.
	cp -p "$CATALOG" "$TXN/bak.catalog" && cp -p "$PIN_FILE" "$TXN/bak.pin" || die "backing up the catalog and pin failed"
	: >"$TXN/bak.done"
	mv "$PLUGIN" "$TXN/bak.plugin" || die "replacing $PLUGIN failed, the previous installation was restored"
	mv "$work" "$PLUGIN" || die "replacing $PLUGIN failed, the previous installation was restored"
	mv -f "$TXN/new.catalog" "$CATALOG" || die "replacing the catalog failed, the previous installation was restored"
	mv -f "$TXN/new.pin" "$PIN_FILE" || die "replacing the pin failed, the previous installation was restored"
	: >"$TXN/committed"

	stage_changes || die "the installation is complete but staging it failed, run: bash omp-port/sync-upstream.sh recover"
	rm -rf "$TXN" || die "the installation is complete but removing $TXN failed, run: bash omp-port/sync-upstream.sh recover"
	TXN_OWNED=""

	changed=$(git status --porcelain -- "$PLUGIN" | wc -l | tr -d ' ')
	printf '\npin      %s -> %s\nversion  %s -> %s (upstream %s)\ncounts   %s skills, %s playbooks, %s principles, %s agents\nchanged  %s files under %s\n' \
		"${pin:0:7}" "${newpin:0:7}" "$cur" "$next" "$up" "$n" "$p" "$k" "$a" "$changed" "$PLUGIN"
	[ -z "$untiered" ] || printf '%s\n' "$untiered" | sed 's/^/untiered /'
}

# ---- the commands ---------------------------------------------------------------------------

cmd_sync() {
	local target="${1:-}" pin touched dirty owned cur next
	pin=$(read_pin)
	[ -n "$target" ] || target=$(upstream_head)
	[[ $target =~ ^[0-9a-f]{40}$ ]] || die "target must be a full 40-hex sha, got '$target'"
	touched=$(pstack_log | cut -f1)
	grep -qxF "$target" <<<"$touched" ||
		die "target $target does not touch pstack/, the pin must be a commit that touched pstack/"
	if [ "$pin" = "$target" ]; then
		printf 'sync-upstream: already at %s, nothing to do\n' "$target"
		return 0
	fi
	# The whole plugin directory is replaced, and owned paths and the manifest are carried across
	# it, so an uncommitted owned file is not a reason to refuse. An edit to anything else is.
	owned=$(owned_paths)
	dirty=$(git status --porcelain -- "$PLUGIN" | sed 's/^...//' |
		owned="$owned" awk -v root="$PLUGIN/" '
			BEGIN { n = split(ENVIRON["owned"], o, "\n") }
			{
				skip = ($0 == root "package.json")
				for (i = 1; i <= n; i++)
					if (o[i] != "" && ($0 == root o[i] || index($0, root o[i] "/") == 1)) skip = 1
				if (!skip) print
			}')
	if [ -n "$(printf '%s' "$dirty" | tr -d '[:space:]')" ]; then
		printf '%s\n' "$dirty" >&2
		die "uncommitted changes the build would destroy, commit or stash them first"
	fi
	cur=$(current_version)
	next=$(derive_version sync "$cur")
	do_build "$target" "$pin" "$next" yes
}

cmd_rebuild() {
	local pin cur
	pin=$(read_pin)
	cur=$(current_version)
	do_build "$pin" "$pin" "$(derive_version rebuild "$cur")" no
}

cmd_release() {
	local pin cur
	pin=$(read_pin)
	cur=$(current_version)
	do_build "$pin" "$pin" "$(derive_version release "$cur")" no
}

usage() { awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$HERE/sync-upstream.sh"; }

main() {
	case "${1:-}" in
	check | -h | --help) ;;
	*) acquire_lock "$@" ;;
	esac
	case "${1:-}" in
	check)
		local pin target
		pin=$(read_pin)
		target=$(upstream_head)
		printf 'target %s\n' "$target" >&2
		[ -z "${SYNC_TARGET_OUT:-}" ] || printf '%s\n' "$target" >"$SYNC_TARGET_OUT"
		commits_since "$pin"
		;;
	-h | --help) usage ;;
	recover)
		recover_txn explicit
		;;
	rebuild)
		recover_txn
		cmd_rebuild
		;;
	release)
		recover_txn
		cmd_release
		;;
	*)
		recover_txn
		cmd_sync "${1:-}"
		;;
	esac
}

# Sourced by a test harness, the functions are available and nothing runs.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then main "$@"; fi
