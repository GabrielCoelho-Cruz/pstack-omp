#!/usr/bin/env bash
# The build pipeline, gate patterns, and live-tree counts shared by sync-upstream.sh and
# check-port.sh. Port-only file, never upstream. Paths resolve from this file's own location, so
# sourcing it before or after a cd makes no difference.
#
# Every function here fails closed. A grep that exits 2 is an inspection failure, not a clean
# scan, so each grep status is captured on its own and only 0 (match) and 1 (no match) are
# answers. An enumeration that fails is a failed build, never an empty one.

PORT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$(cd "$PORT_DIR/.." && pwd -P)
CANON="${CANON:-/tmp/cursor-plugins}"
RULES="${RULES:-$PORT_DIR/rules.sed}"
UPSTREAM_URL=https://github.com/cursor/plugins

# The routing agents are the exact set setup-pstack may override in task.agentModelOverrides, and
# the exact files agents-extra must ship. Nothing else is a routing agent.
ROUTING_AGENTS="pstack_fast pstack_judgment pstack_panel_1 pstack_panel_2 pstack_panel_3 pstack_panel_4"

PAT_SLUG='\b(claude-[a-z0-9.-]+|gpt-[0-9][a-z0-9.-]*|grok-[a-z0-9.-]+|gemini-[a-z0-9.-]+|opus-[a-z0-9.-]+)\b'
PAT_CAPS='omp (has no|does not support|cannot|lacks) [A-Za-z`_.:-]+'
# What the rules and patches must leave nothing of. The first group is Cursor mechanics. The rest
# is task-shaped syntax omp does not accept (a task `environment` field, the old multi-select
# spellings), a tool-shaped `hub` (omp has no such tool), Cursor install and transcript paths, a
# product the port does not ship, old install roots, and prose that tells the agent to set a
# per-call `model`, which is configured through task.agentModelOverrides and never per call. Each
# negative description of an absent field has to be written without the offending spelling.
PAT_RESIDUE='cursor-team-kit|/deslop|run_in_background|~/\.cursor/|AskQuestion|cloud_base_branch|~/\.omp/skills/|~/\.omp/pstack/|environment[[:space:]]*:|allowMultiple|allow_multiple|(^|[^[:alnum:]_-])hub([^[:alnum:]_-]|$)|Custom Mode|/add-plugin|agent-transcripts|RepoPrompt|~/\.agents/skills|~/\.omp/plugins/node_modules/pstack|Set `model` to|`model` set to|omit `model` for|model.*set to its configured entry'
# Every conflict git writes is bracketed by <<<<<<< and >>>>>>>, so a bare ======= needs no
# branch of its own and a seven-character setext underline stops being a false positive.
PAT_MARKER='^(<{7} |\|{7}( |$)|>{7} )'
# The last model-slug rule in rules.sed is a catch-all, so an upstream slug nobody wrote a tiered
# rule for still comes out model-agnostic. What it rewrote is reported, never silently accepted,
# and it is found by rebuilding without it and grepping for what it would have matched. Its
# replacement text is how the line is identified, so it has to stay unique in rules.sed, and its
# left side is read off that line rather than restated here where the two could drift apart.
CATCHALL_REPL='your configured model for this role'

# Writes the catch-all's left side to stdout. Nothing when rules.sed has no catch-all, nonzero
# when rules.sed cannot be read.
catchall_pat() {
	local line st=0
	line=$(grep -F -- "$CATCHALL_REPL" "$RULES") || st=$?
	[ "$st" -le 1 ] || return 1
	[ -n "$line" ] || return 0
	printf '%s\n' "$line" | head -n 1 |
		sed -E "s@^s(.)(.*)\1${CATCHALL_REPL}\1g?\$@\2@"
}

# Lines on stdin, as a number. wc pads its answer on some platforms, awk does not.
count_lines() { awk 'END { print NR }'; }

# Skills, playbooks, and principle leaves under a plugin root, printed as one line. The
# generator and the gate call this, so they cannot disagree on what counts as a skill. A find
# that fails is a failure, not a count of zero.
port_counts() {
	local root="$1" n p k
	n=$(find "$root/skills" -mindepth 1 -maxdepth 1 -type d) || return 1
	p=$(find "$root/skills/poteto-mode/playbooks" -mindepth 1 -maxdepth 1 -type f -name '*.md') || return 1
	k=$(find "$root/skills" -mindepth 1 -maxdepth 1 -type d -name 'principle-*') || return 1
	printf '%s %s %s\n' "$(printf '%s\n' "$n" | sed '/^$/d' | count_lines)" \
		"$(printf '%s\n' "$p" | sed '/^$/d' | count_lines)" \
		"$(printf '%s\n' "$k" | sed '/^$/d' | count_lines)"
}

# The port is a build, not a maintained tree. plugins/pstack/{skills,agents} is build_tree(pin)
# plus prepare_tree, so upstream text can never conflict with port text. rules.sed rewrites
# mechanics, patches/ carries port-only text and code, owned.txt carries port-only files, and
# agents-extra carries the routing agent definitions that prepare_tree adds to agents/.

ensure_canon() {
	if [ ! -d "$CANON/.git" ]; then
		git clone --depth 1 --filter=blob:none --sparse "$UPSTREAM_URL" "$CANON" || return 1
		git -C "$CANON" sparse-checkout set pstack || return 1
	fi
	local s
	for s in "$@"; do
		git -C "$CANON" cat-file -e "$s^{commit}" 2>/dev/null ||
			git -C "$CANON" fetch --depth 1 --filter=blob:none origin "$s" || return 1
	done
}

# Step 1, upstream text as it is, with pstack/ stripped so skills and agents land at the root.
extract_upstream() {
	local sha="$1" work="$2"
	(
		set -o pipefail
		git -C "$CANON" archive "$sha" pstack/skills pstack/agents |
			tar -x --strip-components=1 -C "$work"
	) || return 1
	[ -d "$work/skills" ] && [ -d "$work/agents" ]
}

# Step 2, the substitution table. A binary file is skipped rather than corrupted, and that is what
# grep -I reports, as status 1, when the empty pattern does not match it. Status 2 is a file grep
# could not read, which is a failed build. The file list is written out first so a find that fails
# is seen, which a process substitution would hide.
apply_rules() {
	local work="$1" rules="$2" list f st
	list=$(mktemp) || return 1
	if ! find "$work" -type f -print0 >"$list"; then
		rm -f "$list"
		return 1
	fi
	while IFS= read -r -d '' f; do
		st=0
		grep -Iq '' "$f" || st=$?
		case "$st" in
		0) sed -E -i -f "$rules" "$f" || { rm -f "$list"; return 1; } ;;
		1) ;;
		*) echo "apply_rules: grep could not read $f" >&2; rm -f "$list"; return 1 ;;
		esac
	done <"$list"
	rm -f "$list"
}

# Step 3, the port's own text and code. A patch that no longer applies is a hard stop, because the
# alternative is shipping a tree that silently lost the port's behavior. Fuzz is refused for the
# same reason, and a reject or backup file left behind means a hunk did not land cleanly.
apply_patches() {
	local work="$1" p stray
	for p in "$PORT_DIR"/patches/*.patch; do
		[ -e "$p" ] || continue
		patch -p1 -d "$work" --fuzz=0 --no-backup-if-mismatch <"$p" || return 1
	done
	stray=$(find "$work" \( -name '*.rej' -o -name '*.orig' \)) || return 1
	if [ -n "$stray" ]; then
		echo "apply_patches: patch left stray files: $stray" >&2
		return 1
	fi
}

# Frontmatter surgery for step 3b. $2 is "set" or "clear". The frontmatter is the block between
# the first line, which has to be `---`, and the next `---`. "set" leaves exactly one
# `disable-model-invocation: true` line in it and "clear" leaves none. Nothing outside the block is
# touched. A file without a closed frontmatter block is an error, not a skip.
set_hide_flag() {
	local f="$1" mode="$2" tmp
	tmp=$(mktemp) || return 1
	if ! awk -v mode="$mode" '
		BEGIN { state = 0; done = 0 }
		state == 0 {
			if ($0 != "---") exit 3
			print; state = 1; next
		}
		state == 1 {
			if ($0 == "---") {
				if (mode == "set" && !done) print "disable-model-invocation: true"
				print; state = 2; next
			}
			if ($0 ~ /^disable-model-invocation:/) {
				if (mode == "set" && !done) { print "disable-model-invocation: true"; done = 1 }
				next
			}
			print; next
		}
		{ print }
		END { if (state != 2) exit 3 }
	' "$f" >"$tmp"; then
		rm -f "$tmp"
		echo "set_hide_flag: $f has no closed frontmatter block" >&2
		return 1
	fi
	cat "$tmp" >"$f" || { rm -f "$tmp"; return 1; }
	rm -f "$tmp"
}

# Step 3b, catalog visibility. Upstream marks almost every skill `disable-model-invocation: true`
# because Cursor surfaces them through the slash menu and the pinned Custom Mode. omp maps that key
# to `hide`, which keeps the skill out of the model's skill list. A hidden skill is still readable
# as skill://<name> and runnable as /skill:<name>, but nothing tells the model it exists, so only a
# router that names it or the user's own words reach it. Every workflow skill is listed instead,
# which is what lets the model route to it. Two groups stay hidden on purpose. Principle leaves:
# poteto-mode's Principles index names each one and the agent reads it on demand, which keeps 24
# one-rule descriptions out of every prompt. make-bot-ui: it has no omp counterpart for creating,
# storing, or waking a routine, so the model must not pick it unprompted. bro, ketchup,
# in-your-own-words, and correct are plain reply and correction skills the model should offer, so
# they stay listed. The owned skills are added later by prepare_tree and keep their own metadata.
apply_visibility() {
	local work="$1" f name st=0
	for f in "$work"/skills/*/SKILL.md; do
		[ -e "$f" ] || { echo "apply_visibility: no SKILL.md under $work/skills" >&2; return 1; }
		name=$(basename "$(dirname "$f")")
		case "$name" in
		principle-* | make-bot-ui) set_hide_flag "$f" set || st=1 ;;
		*) set_hide_flag "$f" clear || st=1 ;;
		esac
	done
	return "$st"
}

# A scratch build of upstream skills and agents plus the rules, patches, and visibility. It writes
# only into $work. The owned paths and the routing agents come later, from prepare_tree.
build_tree() {
	local sha="$1" work="$2"
	extract_upstream "$sha" "$work" &&
		apply_rules "$work" "$RULES" &&
		apply_patches "$work" &&
		apply_visibility "$work"
}

# The owned paths, one per line, normalized and relative to plugins/pstack. Comments and blank
# lines are the file's. The whole file is validated before anything is printed, so a caller never
# acts on a partial list. Rejected: an absolute path, a `..` component, an entry that normalizes to
# nothing, a duplicate, two entries where one contains the other, and anything under agents/, which
# is a generated directory the port does not own.
owned_paths() {
	local file="$PORT_DIR/owned.txt" line part norm q out="" bad=0 trav
	local -a parts kept
	[ -f "$file" ] && [ -r "$file" ] || { echo "owned.txt: $file is not readable" >&2; return 1; }
	while IFS= read -r line || [ -n "$line" ]; do
		line=${line%%#*}
		line="${line#"${line%%[![:space:]]*}"}"
		line="${line%"${line##*[![:space:]]}"}"
		[ -n "$line" ] || continue
		case "$line" in
		/*) echo "owned.txt: absolute path: $line" >&2; bad=1; continue ;;
		esac
		kept=()
		trav=0
		IFS=/ read -r -a parts <<<"$line"
		for part in "${parts[@]}"; do
			case "$part" in
			'' | .) ;;
			..) trav=1; break ;;
			*) kept+=("$part") ;;
			esac
		done
		if [ "$trav" -eq 1 ]; then
			echo "owned.txt: path traversal: $line" >&2; bad=1; continue
		fi
		if [ "${#kept[@]}" -eq 0 ]; then
			echo "owned.txt: empty path: $line" >&2; bad=1; continue
		fi
		norm=$(IFS=/; printf '%s' "${kept[*]}")
		case "$norm" in
		agents | agents/*) echo "owned.txt: agents/ is generated, not owned: $line" >&2; bad=1; continue ;;
		esac
		while IFS= read -r q; do
			[ -n "$q" ] || continue
			if [ "$q" = "$norm" ]; then
				echo "owned.txt: duplicate entry: $norm" >&2; bad=1
			else
				case "$norm/" in "$q"/*) echo "owned.txt: $norm is inside $q" >&2; bad=1 ;; esac
				case "$q/" in "$norm"/*) echo "owned.txt: $q is inside $norm" >&2; bad=1 ;; esac
			fi
		done <<<"$out"
		out="$out$norm"$'\n'
	done <"$file"
	[ "$bad" -eq 0 ] || return 1
	[ -n "$out" ] || { echo "owned.txt: no entries" >&2; return 1; }
	printf '%s' "$out"
}

# Restores one owned path into $work. The worktree wins, so an edit that is not committed yet
# survives the build. A path the worktree lacks is read from HEAD, straight into $work, and the
# live checkout is never touched. A path missing from both is a broken owned.txt.
restore_owned_path() {
	local work="$1" p="$2" src="$REPO_ROOT/plugins/pstack/$2" dest="$1/$2"
	if [ -e "$src" ] || [ -L "$src" ]; then
		rm -rf "$dest" && mkdir -p "$(dirname "$dest")" && cp -a "$src" "$dest" || {
			echo "prepare_tree: could not copy $src" >&2
			return 1
		}
	elif git -C "$REPO_ROOT" cat-file -e "HEAD:plugins/pstack/$p" 2>/dev/null; then
		rm -rf "$dest" || return 1
		(
			set -o pipefail
			git -C "$REPO_ROOT" archive HEAD -- "plugins/pstack/$p" |
				tar -x --strip-components=2 -C "$work"
		) || {
			echo "prepare_tree: could not read $p from HEAD" >&2
			return 1
		}
		[ -e "$dest" ] || {
			echo "prepare_tree: HEAD holds $p but extracting it produced nothing" >&2
			return 1
		}
	else
		echo "prepare_tree: owned path $p is in neither the worktree nor HEAD" >&2
		return 1
	fi
}

# The front-matter `name:` of an agent file, empty when it has none.
agent_name() {
	awk '
		NR == 1 { if ($0 != "---") exit; next }
		$0 == "---" { exit }
		/^name:/ { sub(/^name:[[:space:]]*/, ""); gsub(/^["'"'"']|["'"'"']$/, ""); print; exit }
	' "$1"
}

# Copies agents-extra into agents/. The directory has to hold exactly the routing agents, one
# file each, named for the agent it defines. A name that an upstream agent already uses, by file
# or by front matter, is a collision and stops the build, because the routing agent would shadow
# or be shadowed. agents-extra itself is not an agent root and stays where prepare_tree put it.
install_routing_agents() {
	local work="$1" dir="$1/agents-extra" entries want name f other
	[ -d "$dir" ] || { echo "prepare_tree: $dir is missing" >&2; return 1; }
	entries=$(find "$dir" -mindepth 1 -maxdepth 1 -exec basename {} \;) || return 1
	entries=$(printf '%s\n' "$entries" | sed '/^$/d' | sort)
	want=$(for name in $ROUTING_AGENTS; do printf '%s.md\n' "$name"; done | sort)
	if [ "$entries" != "$want" ]; then
		echo "prepare_tree: agents-extra must hold exactly $ROUTING_AGENTS, found: $(printf '%s' "$entries" | tr '\n' ' ')" >&2
		return 1
	fi
	for name in $ROUTING_AGENTS; do
		f="$dir/$name.md"
		[ -f "$f" ] || { echo "prepare_tree: $f is not a file" >&2; return 1; }
		[ "$(agent_name "$f")" = "$name" ] || {
			echo "prepare_tree: $f must declare name: $name" >&2
			return 1
		}
		[ ! -e "$work/agents/$name.md" ] || {
			echo "prepare_tree: upstream already ships agents/$name.md" >&2
			return 1
		}
	done
	for other in "$work"/agents/*.md; do
		[ -e "$other" ] || continue
		name=$(agent_name "$other")
		case " $ROUTING_AGENTS " in
		*" $name "*) echo "prepare_tree: upstream agent $other declares routing name $name" >&2; return 1 ;;
		esac
	done
	for name in $ROUTING_AGENTS; do
		cp "$dir/$name.md" "$work/agents/$name.md" || return 1
	done
}

# Step 4, and it mutates only $work. The owned paths are carried in from the worktree, or from HEAD
# when the worktree lacks one, and the routing agents are copied into agents/. Any failure returns
# nonzero and leaves the live plugin, the pin, the metadata, and the index exactly as they were,
# because none of them is touched here. The caller decides what to do with $work afterwards.
prepare_tree() {
	local work="$1" owned p
	[ -d "$work/skills" ] && [ -d "$work/agents" ] || {
		echo "prepare_tree: $work holds no built skills and agents" >&2
		return 1
	}
	owned=$(owned_paths) || return 1
	while IFS= read -r p; do
		[ -n "$p" ] || continue
		restore_owned_path "$work" "$p" || return 1
	done <<<"$owned"
	install_routing_agents "$work"
}

# Distinct slugs the catch-all rewrote at <sha>, one per line. Nothing is printed when the
# catch-all rewrote nothing. A failed extraction, rule run, or grep is a nonzero status, never an
# empty list.
untiered_slugs() {
	local sha="$1" rules work pat out st=0 gst=0
	pat=$(catchall_pat) || return 1
	[ -n "$pat" ] || return 0
	rules=$(mktemp) || return 1
	work=$(mktemp -d) || { rm -f "$rules"; return 1; }
	grep -vF -- "$CATCHALL_REPL" "$RULES" >"$rules" || gst=$?
	if [ "$gst" -le 1 ] && extract_upstream "$sha" "$work" && apply_rules "$work" "$rules"; then
		gst=0
		out=$(grep -rohIE -- "$pat" "$work") || gst=$?
		if [ "$gst" -le 1 ]; then
			[ -z "$out" ] || printf '%s\n' "$out" | sort -u
		else
			st=1
		fi
	else
		st=1
	fi
	rm -rf "$work" "$rules"
	return "$st"
}
