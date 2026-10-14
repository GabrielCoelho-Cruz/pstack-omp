#!/usr/bin/env bash
# Gate for the omp port of pstack. Port-only file, never upstream.
# Usage: bash omp-port/check-port.sh [canonical-clone]
# The argument, or CANON, is the cursor/plugins clone the reproducible check builds from.
#
# The gate fails closed. Every external command whose result it relies on is run on its own and its
# exit status is read: grep 0 is a match, 1 is no match, anything higher is an inspection failure.
# diff and cmp use the same convention, 0 equal, 1 changed, higher is an inspection failure. An
# inspection failure is a FAIL of the check that needed the answer, never a pass and never a skip,
# and a later check that succeeds cannot hide it, because each failure sets the final verdict.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
LIB_ROUTING="${ROUTING_AGENTS:-}"
CANON="${1:-$CANON}"
cd "$REPO_ROOT" || {
	echo "check-port: cannot enter $REPO_ROOT"
	echo "check-port: FAIL"
	exit 1
}
fail=0
report() { printf '%-28s %s\n' "$1" "$2"; }
violate() { fail=1; printf '  %s\n' "$1"; }

PSTACK=plugins/pstack
FANOUT=plugins/fan-out
MARKET=.omp-plugin/marketplace.json
ALLOW=omp-port/slug-allowlist.txt
ROUTER=$PSTACK/skills/poteto-mode/SKILL.md

# The routing set is the exact agent set setup-pstack may override. Nothing else is a routing agent.
ROUTING_AGENTS="pstack_fast pstack_judgment pstack_panel_1 pstack_panel_2 pstack_panel_3 pstack_panel_4"
COMPAT_AGENTS="poteto-agent comment-sicko"
OWNED_ROOTS="agents-extra extensions LICENSE README.md skills/omp-mechanics skills/pstack-omp THIRD_PARTY_NOTICES.md"
ROUTED_SKILLS="how why reflect arena interrogate architect swarm"
HIDDEN_SKILLS="make-bot-ui"
VISIBLE_SKILLS="bro ketchup in-your-own-words correct"

TMP=$(mktemp -d) || {
	echo "check-port: cannot create a temporary directory"
	echo "check-port: FAIL"
	exit 1
}
trap 'rm -rf "$TMP"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

# ---- the building blocks every check shares -------------------------------------------------

# Verdict lines. A check collects its problems in P and calls finish once.
P=""
p_add() { P="$P$1"$'\n'; }
finish() {
	local label="$1" ok="$2" l
	if [ -n "$P" ]; then
		report "$label" "FAIL"
		while IFS= read -r l; do [ -n "$l" ] && violate "$l"; done <<<"$P"
	else
		report "$label" "PASS  $ok"
	fi
	P=""
}

# grep with a status that cannot be mistaken. G_OUT holds the matches, G_ERR what grep said when it
# could not inspect. Returns 0 match, 1 no match, 2 inspection failure.
G_OUT="" G_ERR=""
gscan() {
	local pat="$1" st
	shift
	G_OUT="" G_ERR=""
	if [ "$#" -eq 0 ]; then
		G_ERR="no files to inspect"
		return 2
	fi
	G_OUT=$(grep -IHn -E -e "$pat" -- "$@" 2>"$TMP/grep.err")
	st=$?
	if [ "$st" -le 1 ]; then return "$st"; fi
	G_ERR=$(tr '\n' ' ' <"$TMP/grep.err")
	[ -n "$G_ERR" ] || G_ERR="grep exited $st"
	return 2
}

# Does <file> hold <pattern>? 0 yes, 1 no, 2 the file could not be read or grep failed.
# $3 is optional extra grep flags such as -F or -i.
file_has() {
	local file="$1" pat="$2" flag="${3:--E}" st
	if [ ! -f "$file" ] || [ ! -r "$file" ]; then return 2; fi
	grep -q "$flag" -e "$pat" -- "$file" 2>/dev/null
	st=$?
	if [ "$st" -le 1 ]; then return "$st"; fi
	return 2
}

# Record a missing or unreadable required file as an inspection failure of the current check.
need_file() {
	if [ -f "$1" ] && [ -r "$1" ]; then return 0; fi
	p_add "inspection failure: $1 is missing or unreadable"
	return 1
}

# require <file> <pattern> <grep-flag> <message>. The message is a violation only when the file was
# read and the text is genuinely absent.
require() {
	local file="$1" pat="$2" flag="$3" msg="$4" st
	file_has "$file" "$pat" "$flag"
	st=$?
	case "$st" in
	0) ;;
	1) p_add "$file: $msg" ;;
	*) p_add "inspection failure: cannot read $file" ;;
	esac
}

# The frontmatter block of a markdown file, between its first two --- lines. Status 3 when the file
# does not open with one or never closes it.
fm_block() {
	awk '
		NR == 1 { if ($0 ~ /^---[ \t\r]*$/) started = 1; next }
		started && !done && /^---[ \t\r]*$/ { done = 1; exit }
		started && !done { print }
		END { if (!started || !done) exit 3 }
	' "$1"
}

# Value of a top-level frontmatter key, quotes stripped. Empty output with status 0 means the key is
# absent. Status 3 is a file with no frontmatter, anything else a read failure.
fm_value() {
	local block st
	block=$(fm_block "$1")
	st=$?
	[ "$st" -eq 0 ] || return "$st"
	printf '%s\n' "$block" | awk -v k="$2" '
		index($0, k ":") == 1 {
			v = substr($0, length(k) + 2)
			sub(/^[ \t]+/, "", v); sub(/[ \t\r]+$/, "", v)
			print v
			exit
		}' | sed -E "s/^[\"']//; s/[\"']\$//"
}

# ---- the text the gate reads ----------------------------------------------------------------

SCAN_FILES=()
MD_FILES=()
enum_status=0
if find "$PSTACK" "$FANOUT" -name node_modules -prune -o -type f \
	\( -name '*.md' -o -name '*.mjs' -o -name '*.ts' -o -name '*.sh' -o -name '*.js' \) -print0 |
	LC_ALL=C sort -z >"$TMP/files.z"; then
	while IFS= read -r -d '' f; do SCAN_FILES+=("$f"); done <"$TMP/files.z"
else
	enum_status=1
fi
# The root documents are shipped prose too, and a missing one is an inspection failure rather than
# a file that quietly drops out of scope.
SCAN_FILES+=(README.md PORTING.md)
for f in "${SCAN_FILES[@]}"; do
	case "$f" in *.md) MD_FILES+=("$f") ;; esac
done

P=""
[ "$enum_status" -eq 0 ] || p_add "inspection failure: enumerating $PSTACK and $FANOUT failed"
for f in "${SCAN_FILES[@]}"; do
	[ -f "$f" ] && [ -r "$f" ] || p_add "inspection failure: $f is missing or unreadable"
done
finish "scope" "${#SCAN_FILES[@]} files in both plugins, the extension, README.md, PORTING.md"

# An audited exception is `path:line<TAB>pattern<TAB>reason`, where pattern is one of slug, caps,
# or residue. An exception covers that one pattern on that one line, nothing else. Illustrative
# prose only, never a real prescription. Anything not listed here passes on its own merits. The path
# is relative to plugins/pstack for a file under it and to the repository root for any other.
allowed() {
	[ -f "$ALLOW" ] || return 1
	awk -F'\t' -v k="$1" -v p="$2" '$1 == k && $2 == p { hit = 1 } END { exit !hit }' "$ALLOW"
}
allow_count() { awk -F'\t' -v p="$2" '$0 !~ /^#/ && $2 == p' "$1" | wc -l; }
allow_file() { if [ -e "$PSTACK/$1" ]; then printf '%s\n' "$PSTACK/$1"; else printf '%s\n' "$1"; fi; }
# The gate patterns live in omp-port/lib.sh, one source shared with the sync script.
pattern_for() {
	case "$1" in
	slug) printf '%s\n' "$PAT_SLUG" ;;
	caps) printf '%s\n' "$PAT_CAPS" ;;
	residue) printf '%s\n' "$PAT_RESIDUE" ;;
	esac
}

if [ -e "$ALLOW" ] && { [ ! -f "$ALLOW" ] || [ ! -r "$ALLOW" ]; }; then
	P=""
	p_add "inspection failure: $ALLOW is unreadable"
	finish "allowlist file" ""
fi

scan() {
	local pat="$1" label="$2" name="$3" st line f n key bad="" cnt=0
	gscan "$pat" "${SCAN_FILES[@]}"
	st=$?
	if [ "$st" -ge 2 ]; then
		P=""
		p_add "inspection failure: grep could not scan for $name: $G_ERR"
		finish "$label" ""
		return
	fi
	if [ "$st" -eq 0 ]; then
		while IFS=: read -r f n _; do
			[ -n "$f" ] || continue
			key="${f#$PSTACK/}:$n"
			case "$f" in $PSTACK/*) ;; *) key="$f:$n" ;; esac
			allowed "$key" "$name" || bad="$bad$f:$n"$'\n'
		done <<<"$G_OUT"
	fi
	P="$bad"
	[ -f "$ALLOW" ] && cnt=$(allow_count "$ALLOW" "$name")
	finish "$label" "clean, $cnt audited $name exception(s)"
}

scan "$PAT_SLUG" "model-agnostic" slug

# ---- the pattern library the scans consume --------------------------------------------------

# omp-port/lib.sh owns the residue pattern. The gate refuses to run on a library that dropped a
# branch the package contract needs, because the scan would then pass for the wrong reason.
P=""
for b in 'environment[[:space:]]*:' 'allowMultiple' 'allow_multiple' '(^|[^[:alnum:]_-])hub([^[:alnum:]_-]|$)' \
	'Custom Mode' '/add-plugin' 'agent-transcripts' 'RepoPrompt' '~/\.agents/skills' \
	'~/\.omp/plugins/node_modules/pstack' 'Set `model` to' '`model` set to' 'omit `model` for' \
	'model.*set to its configured entry'; do
	case "$PAT_RESIDUE" in *"$b"*) ;; *) p_add "omp-port/lib.sh PAT_RESIDUE lacks the branch: $b" ;; esac
done
finish "residue pattern" "PAT_RESIDUE carries every required branch"
type prepare_tree >/dev/null 2>&1 || p_add "omp-port/lib.sh defines no prepare_tree"
type build_tree >/dev/null 2>&1 || p_add "omp-port/lib.sh defines no build_tree"
[ "$LIB_ROUTING" = "$ROUTING_AGENTS" ] || p_add "omp-port/lib.sh ROUTING_AGENTS is [$LIB_ROUTING], the settled set is [$ROUTING_AGENTS]"
finish "build interface" "build_tree and prepare_tree are defined"

# ---- model levers ---------------------------------------------------------------------------

# Role instructions must name an omp lever. /model sets the chat model, task.agentModelOverrides
# sets a per-agent model. Each required file is judged on its own so one cannot vouch for the other.
for f in "$PSTACK/skills/setup-pstack/SKILL.md" "$PSTACK/skills/poteto-mode/SKILL.md"; do
	P=""
	require "$f" 'task.agentModelOverrides' -F "must name task.agentModelOverrides"
	finish "model lever $(basename "$(dirname "$f")")" "task.agentModelOverrides named"
done
P=""
require "$PSTACK/skills/setup-pstack/SKILL.md" '/model' -F "must tell the user to pick the chat model with /model"
finish "chat-model lever" "/model named in setup-pstack"

# Every routed skill and the setup skill have to find the shipped routes. The adapter says how a
# dispatch is made, the setup reference says what each exact agent name means.
P=""
for s in $ROUTED_SKILLS; do
	f="$PSTACK/skills/$s/SKILL.md"
	require "$f" 'skill://pstack-omp' -F "must point at skill://pstack-omp"
	require "$f" 'references/setup-pstack-config.md' -F "must point at the setup reference references/setup-pstack-config.md"
done
finish "routed skills" "$(printf '%s\n' $ROUTED_SKILLS | wc -l | tr -d ' ') routed skills point at the adapter and the setup reference"

# A diverse-model review is a property of the reviewer, not a named slug.
P=""
for f in interrogate arena reflect; do
	require "$PSTACK/skills/$f/SKILL.md" 'different (model )?(family|provider)|separate model family' -iE \
		"no model-diversity property stated"
done
finish "review diversity" "stated as a property"

# A capability claim pinned to a version rots on the next upgrade, exactly like a
# hardcoded model slug. Depend on a probe or a conditional instead.
P=""
gscan 'omp[/ ]?1[0-9]+\.[0-9]+(\.[0-9]+)?' "${MD_FILES[@]}"
st=$?
if [ "$st" -ge 2 ]; then
	p_add "inspection failure: grep could not scan for version pins: $G_ERR"
elif [ "$st" -eq 0 ]; then
	while IFS= read -r v; do [ -n "$v" ] && p_add "version-pinned: $v"; done <<<"$G_OUT"
fi
finish "version-agnostic" "no version-pinned capability claim"

scan "$PAT_CAPS" "capability claims" caps

scan "$PAT_RESIDUE" "cursor residue" residue

# The residue pattern covers the plain spellings. A quoted key or an assignment is the same task
# environment field in another dress.
P=""
gscan "[\"'\`]environment[\"'\`][[:space:]]*:|(^|[^[:alnum:]_])environment[[:space:]]*=[[:space:]]*[\"'\`]" "${SCAN_FILES[@]}"
st=$?
if [ "$st" -ge 2 ]; then
	p_add "inspection failure: grep could not scan for task environment spellings: $G_ERR"
elif [ "$st" -eq 0 ]; then
	while IFS= read -r v; do [ -n "$v" ] && p_add "task environment spelling: ${v%%:*}"; done < <(printf '%s\n' "$G_OUT" | cut -d: -f1,2)
fi
finish "task environment" "no task environment field in any spelling"

# omp's task wire has no readonly field, so a bare `readonly: true` task parameter
# is silently ignored. Read-only posture must be a brief-level tool grant plus a
# write ban, with the skill stating omp cannot enforce it.
P=""
gscan '`readonly`:\s*`?true`?|readonly:\s*true' "${MD_FILES[@]}"
st=$?
if [ "$st" -ge 2 ]; then
	p_add "inspection failure: grep could not scan for readonly: $G_ERR"
elif [ "$st" -eq 0 ]; then
	while IFS= read -r r; do [ -n "$r" ] && p_add "unenforceable readonly: ${r%%:*}"; done < <(printf '%s\n' "$G_OUT" | cut -d: -f1,2)
fi
finish "readonly posture" "read-only stated as brief posture"

# The upstream guide is not shipped. A pointer to it is live only when it names a file this package
# carries, and none does, so the only tolerated mention is a link to the pinned upstream commit,
# written with its full sha and labelled as upstream's own page.
P=""
gscan 'docs/guide/' "${MD_FILES[@]}"
st=$?
if [ "$st" -ge 2 ]; then
	p_add "inspection failure: grep could not scan for guide pointers: $G_ERR"
elif [ "$st" -eq 0 ]; then
	while IFS= read -r l; do
		[ -n "$l" ] || continue
		case "${l%%:*}" in PORTING.md) continue ;; esac
		rest=$(printf '%s\n' "$l" | sed -E 's#https://github\.com/cursor/plugins/(blob|tree)/[0-9a-f]{40}/pstack/docs/guide/[^][ )>"`]*##g')
		case "$rest" in *docs/guide/*) p_add "local pointer to the omitted guide: $(printf '%s' "$l" | cut -d: -f1,2)" ;; esac
	done <<<"$G_OUT"
fi
gscan 'git show origin/main:' "$PSTACK/skills/poteto-mode/playbooks/multi-phase-plan.md" \
	"$PSTACK"/skills/poteto-help/*.md
st=$?
if [ "$st" -ge 2 ]; then
	p_add "inspection failure: grep could not scan for the checker marker residue: $G_ERR"
elif [ "$st" -eq 0 ]; then
	while IFS= read -r l; do [ -n "$l" ] && p_add "fabricated checker marker: $(printf '%s' "$l" | cut -d: -f1,2)"; done <<<"$G_OUT"
fi
finish "guide pointers" "no live local consumer of docs/guide"

# ---- links ----------------------------------------------------------------------------------

linkcheck_js() {
	cat <<'JS'
const fs = require('fs');
const path = require('path');
const roots = process.argv.slice(1);
const problems = [];
let nfiles = 0;
let nrefs = 0;
const fatal = (msg) => { console.error('inspection failure: ' + msg); process.exit(2); };
const RUNTIME = new Set(['omp', 'agent', 'history', 'artifact', 'local', 'proc', 'issue', 'pr', 'mcp', 'ssh']);
const EXTERNAL = new Set(['http', 'https', 'mailto', 'tel', 'data']);
const isTemplate = (s) => /[<>{}*$\u2026]|\.\.\./.test(s);

function stat(p) {
  try { return fs.statSync(p); } catch (e) { if (e.code === 'ENOENT' || e.code === 'ENOTDIR') return null; return fatal(p + ': ' + e.message); }
}
function walk(dir, out) {
  let ents;
  try { ents = fs.readdirSync(dir, { withFileTypes: true }); } catch (e) { fatal(dir + ': ' + e.message); }
  ents.sort((a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : 0));
  for (const e of ents) {
    if (e.name === 'node_modules') continue;
    const p = path.join(dir, e.name);
    let isDir = e.isDirectory();
    let isFile = e.isFile();
    if (e.isSymbolicLink()) {
      const s = stat(p);
      if (!s) { problems.push(`${p}: dangling symlink`); continue; }
      isDir = s.isDirectory();
      isFile = s.isFile();
    }
    if (isDir) walk(p, out);
    else if (isFile && e.name.endsWith('.md')) out.push(p);
  }
}

const skills = new Map();
for (const root of roots) {
  const dir = path.join(root, 'skills');
  let ents;
  try { ents = fs.readdirSync(dir, { withFileTypes: true }); } catch (e) { fatal(dir + ': ' + e.message); }
  for (const e of ents) {
    const p = path.join(dir, e.name);
    const s = stat(p);
    if (s && s.isDirectory()) skills.set(e.name, p);
  }
}
const rootOf = (file) => roots.find((r) => file === r || file.startsWith(r + path.sep));
const owningSkill = (file) => {
  let d = path.dirname(file);
  while (d !== '.' && d !== path.dirname(d)) {
    if (path.dirname(d) === path.join(rootOf(file) || '', 'skills')) return d;
    d = path.dirname(d);
  }
  return null;
};
const within = (target, root) => target === root || target.startsWith(root + path.sep);

// The longest leading run of segments free of template markers has to exist.
function checkPath(file, ln, label, base, rel, keepInside) {
  const segs = rel.split('/').filter((s) => s !== '');
  const concrete = [];
  for (const s of segs) { if (isTemplate(s)) break; concrete.push(s); }
  const templated = concrete.length < segs.length;
  const target = path.normalize(path.join(base, ...concrete));
  if (keepInside && !within(target, keepInside)) {
    problems.push(`${file}:${ln}: ${label} escapes the shipped plugin: ${rel}`);
    return;
  }
  const s = stat(target);
  if (!s) problems.push(`${file}:${ln}: dangling ${templated ? 'template prefix' : 'reference'} ${label}: ${rel}`);
  else if (templated && !s.isDirectory()) problems.push(`${file}:${ln}: template prefix is not a directory ${label}: ${rel}`);
}

function checkSkillRef(file, ln, raw) {
  let ref = raw.replace(/[.,;:!?]+$/, '');
  ref = ref.replace(/[?#].*$/, '');
  nrefs++;
  if (ref === '') { problems.push(`${file}:${ln}: malformed skill:// reference`); return; }
  const segs = ref.split('/');
  const name = segs[0];
  if (isTemplate(name)) return;
  const dir = skills.get(name);
  if (!dir) { problems.push(`${file}:${ln}: skill://${raw} names a skill this package does not ship`); return; }
  if (!stat(path.join(dir, 'SKILL.md'))) { problems.push(`${file}:${ln}: skill://${name} has no SKILL.md`); return; }
  const rest = segs.slice(1).join('/');
  if (rest !== '') {
    let decoded = rest;
    try { decoded = decodeURI(rest); } catch (e) { /* keep raw */ }
    checkPath(file, ln, 'skill://' + name, dir, decoded, dir);
  }
}

function checkLink(file, ln, target0) {
  let target = target0.trim();
  if (target.startsWith('<') && target.endsWith('>')) target = target.slice(1, -1);
  nrefs++;
  if (target === '') { problems.push(`${file}:${ln}: empty link target`); return; }
  if (target.startsWith('#')) return;
  const scheme = /^([A-Za-z][A-Za-z0-9+.-]*):/.exec(target);
  if (scheme) {
    const s = scheme[1].toLowerCase();
    if (EXTERNAL.has(s)) return;
    if (s === 'skill') { checkSkillRef(file, ln, target.replace(/^skill:\/\//i, '')); return; }
    if (RUNTIME.has(s)) {
      if (!/^[A-Za-z][A-Za-z0-9+.-]*:\/\/.+/.test(target) && s !== 'omp') problems.push(`${file}:${ln}: malformed ${s}: reference: ${target}`);
      return;
    }
    problems.push(`${file}:${ln}: unsupported link scheme ${s}: in ${target}`);
    return;
  }
  if (target.startsWith('~')) return;
  // A bare lowercase word with no slash or extension is a placeholder in a prose template, such as
  // the url in [PR](url), not a file the package could carry.
  if (/^[a-z][a-z-]*$/.test(target)) return;
  if (target.startsWith('/')) { problems.push(`${file}:${ln}: absolute local link target ${target}`); return; }
  let rel = target.replace(/[?#].*$/, '');
  try { rel = decodeURI(rel); } catch (e) { /* keep raw */ }
  checkPath(file, ln, 'link', path.dirname(file), rel, rootOf(file));
}

function checkPointer(file, ln, rel) {
  nrefs++;
  const dir = path.dirname(file);
  const own = owningSkill(file);
  const candidates = [dir];
  if (own) candidates.push(own);
  else for (const d of skills.values()) candidates.push(d);
  if (skills.has('poteto-mode')) candidates.push(skills.get('poteto-mode'));
  for (const base of candidates) if (stat(path.join(base, rel))) return;
  problems.push(`${file}:${ln}: dangling pointer ${rel}`);
}

const files = [];
for (const r of roots) walk(r, files);
for (const file of files) {
  let text;
  try { text = fs.readFileSync(file, 'utf8'); } catch (e) { fatal(file + ': ' + e.message); }
  nfiles++;
  const lines = text.split('\n');
  let fence = null;
  lines.forEach((line, i) => {
    const ln = i + 1;
    const f = /^\s{0,3}(`{3,}|~{3,})/.exec(line);
    if (f) {
      if (!fence) fence = f[1][0].repeat(f[1].length);
      else if (f[1][0] === fence[0] && f[1].length >= fence.length) fence = null;
      return;
    }
    for (const m of line.matchAll(/skill:\/\/([^\s)\]`'",;|]*)/g)) checkSkillRef(file, ln, m[1]);
    for (const m of line.matchAll(/(^|[^\w./<>*{}$~-])((?:playbooks|references)\/[A-Za-z0-9_.-]+\.md)\b/g)) checkPointer(file, ln, m[2]);
    if (fence) return;
    const prose = line.replace(/`[^`]*`/g, (c) => ' '.repeat(c.length));
    for (const m of prose.matchAll(/!?\[[^\]]*\]\(\s*(<[^>]*>|[^)\s]*)(?:\s+(?:"[^"]*"|'[^']*'))?\s*\)/g)) {
      if (!/^skill:\/\//i.test(m[1])) checkLink(file, ln, m[1]);
    }
    const def = /^\s{0,3}\[[^\]]+\]:\s*(<[^>]+>|\S+)/.exec(prose);
    if (def && !/^skill:\/\//i.test(def[1])) checkLink(file, ln, def[1]);
    for (const m of prose.matchAll(/\b(?:src|href)="([^"]+)"/g)) checkLink(file, ln, m[1]);
  });
}
for (const p of problems) console.log('V ' + p);
console.log(`S ${nfiles} ${nrefs}`);
process.exit(problems.length ? 1 : 0);
JS
}

P=""
if ! command -v node >/dev/null 2>&1; then
	p_add "inspection failure: node is not installed, the link check cannot run"
	finish "internal links" ""
else
	node -e "$(linkcheck_js)" "$PSTACK" "$FANOUT" >"$TMP/links.out" 2>"$TMP/links.err"
	st=$?
	if [ "$st" -ge 2 ]; then
		p_add "inspection failure: link check could not read the tree: $(tr '\n' ' ' <"$TMP/links.err")"
		finish "internal links" ""
	else
		while IFS= read -r l; do case "$l" in 'V '*) p_add "${l#V }" ;; esac; done <"$TMP/links.out"
		summary=$(awk '$1 == "S" { print $2 " markdown files, " $3 " references" }' "$TMP/links.out")
		finish "internal links" "$summary, every local target resolves"
	fi
fi

# ---- router parity --------------------------------------------------------------------------

# The router prose and the tree must name the same set. A name in the index with no
# leaf misroutes the agent, a leaf the index never names is unreachable.
parity() {
	local label="$1" a="$2" b="$3" pre_a="$4" suf_a="$5" pre_b="$6" suf_b="$7" only_a only_b x
	only_a=$(comm -23 <(printf '%s\n' "$a" | grep .) <(printf '%s\n' "$b" | grep .))
	only_b=$(comm -13 <(printf '%s\n' "$a" | grep .) <(printf '%s\n' "$b" | grep .))
	P=""
	if [ -n "$only_a$only_b" ]; then
		while read -r x; do [ -n "$x" ] && p_add "$pre_a$x$suf_a"; done <<<"$only_a"
		while read -r x; do [ -n "$x" ] && p_add "$pre_b$x$suf_b"; done <<<"$only_b"
	fi
	finish "$label" "$(printf '%s\n' "$a" | grep -c .) names, index and tree agree"
}

# The index lists each principle by title. Its leaf is principle-<title> in kebab case, hyphens
# kept and other punctuation dropped, unless the entry names its leaf outright.
principle_index() {
	awk '/^## Principles/{f=1; next} /^## /{f=0} f && /^- \*\*/' "$ROUTER" | while IFS= read -r entry; do
		if [[ $entry =~ \(\*\*(principle-[a-z-]+)\*\*\) ]]; then
			printf '%s\n' "${BASH_REMATCH[1]}"
		else
			printf '%s\n' "$entry" | sed -E 's/^- \*\*([^*]+)\*\*.*/\1/' | tr 'A-Z' 'a-z' |
				sed -E 's/[^a-z0-9 -]//g; s/ +/-/g; s/-+$//; s/^/principle-/'
		fi
	done | sort -u
}

P=""
if need_file "$ROUTER" && [ -d "$PSTACK/skills/poteto-mode/playbooks" ]; then
	idx_p=$(principle_index) || p_add "inspection failure: reading the principles index of $ROUTER failed"
	tree_p=$(for d in "$PSTACK"/skills/principle-*/; do basename "$d"; done | sort -u) ||
		p_add "inspection failure: listing the principle leaves failed"
	grep -ohE 'playbooks/[a-z-]+\.md' "$ROUTER" >"$TMP/playbooks.raw"
	[ "$?" -le 1 ] || p_add "inspection failure: reading the playbook index of $ROUTER failed"
	idx_b=$(sed 's|playbooks/||; s|\.md$||' "$TMP/playbooks.raw" | sort -u)
	tree_b=$(for f in "$PSTACK"/skills/poteto-mode/playbooks/*.md; do basename "$f" .md; done | sort -u) ||
		p_add "inspection failure: listing the playbooks failed"
else
	p_add "inspection failure: $PSTACK/skills/poteto-mode/playbooks is missing"
	idx_p="" tree_p="" idx_b="" tree_b=""
fi
if [ -n "$P" ]; then
	finish "router parity" ""
else
	parity "principle parity" "$idx_p" "$tree_p" 'index names ' ', no leaf' 'leaf ' ' not in the Principles index'
	parity "playbook parity" "$idx_b" "$tree_b" 'index names playbook ' ', no file' 'playbook ' ' not named in the Playbooks index'
fi

# An exception whose line no longer trips the pattern it was audited for is a standing skip for a
# violation that is gone, and it silently covers whatever that line says next.
if [ -f "$ALLOW" ]; then
	P=""
	while IFS=$'\t' read -r entry name _ || [ -n "$entry" ]; do
		case "$entry" in '' | '#'*) continue ;; esac
		pat=$(pattern_for "$name")
		lineno=${entry##*:}
		if [ -z "$pat" ] || ! [[ $lineno =~ ^[0-9]+$ ]]; then
			p_add "malformed allowlist entry $entry"
			continue
		fi
		target=$(allow_file "${entry%:*}")
		if [ ! -f "$target" ] || [ ! -r "$target" ]; then
			p_add "stale allowlist entry $entry (file missing)"
			continue
		fi
		sed -n "${lineno}p" "$target" >"$TMP/allow.line" || { p_add "inspection failure: reading $target"; continue; }
		file_has "$TMP/allow.line" "$pat" -E
		case "$?" in
		0) ;;
		1) p_add "stale allowlist entry $entry" ;;
		*) p_add "inspection failure: grep failed on allowlist entry $entry" ;;
		esac
	done <"$ALLOW"
	finish "allowlist" "$(grep -cv '^#' "$ALLOW") entries still match their own pattern"
fi

# Claims the published guide makes about pstack, verified as present.
P=""
for s in create-verification-skill maintain-verification-skill swarm poteto-mode; do
	[ -f "$PSTACK/skills/$s/SKILL.md" ] || p_add "guide names /$s, not installed"
done
file_has "$PSTACK/skills/create-verification-skill/SKILL.md" 'features' -iE
case "$?" in
0) ;;
1) p_add "create-verification-skill must build the Feature Map (references/features)" ;;
*) p_add "inspection failure: cannot read $PSTACK/skills/create-verification-skill/SKILL.md" ;;
esac
finish "guide claims" "verification skill, Feature Map, swarm"

# ---- frontmatter, markers, hide flags ---------------------------------------------------------

P=""
NAME_NOTES=""
nskilldirs=0
for d in "$PSTACK"/skills/*/ "$FANOUT"/skills/*/; do
	[ -d "$d" ] || continue
	nskilldirs=$((nskilldirs + 1))
	n=$(basename "$d")
	if [ ! -f "$d/SKILL.md" ] || [ ! -r "$d/SKILL.md" ]; then
		p_add "inspection failure: ${d}SKILL.md is missing or unreadable"
		continue
	fi
	fm=$(fm_value "$d/SKILL.md" name)
	st=$?
	if [ "$st" -ne 0 ]; then
		p_add "${d}SKILL.md: no closed frontmatter block"
	elif [ -z "$fm" ]; then
		p_add "${d}SKILL.md: frontmatter name missing"
	elif [ "$fm" != "$n" ]; then
		# skill:// resolves by frontmatter name, so a different name is a skill its own directory
		# name cannot reach. A name that differs only by case or spaces is upstream's own title and
		# is reported, anything else fails.
		norm=$(printf '%s' "$fm" | tr 'A-Z ' 'a-z-')
		if [ "$norm" = "$n" ]; then
			NAME_NOTES="$NAME_NOTES$n(name '$fm') "
		else
			p_add "${d}SKILL.md: frontmatter name '$fm' is not its directory '$n'"
		fi
	fi
done
finish "frontmatter" "$nskilldirs skills carry a frontmatter name equal to their directory"
[ -z "$NAME_NOTES" ] || report "frontmatter names" "REPORT  title-cased, so skill://<dir> does not resolve: $NAME_NOTES"

P=""
gscan "$PAT_MARKER" "${SCAN_FILES[@]}"
st=$?
if [ "$st" -ge 2 ]; then
	p_add "inspection failure: grep could not scan for conflict markers: $G_ERR"
elif [ "$st" -eq 0 ]; then
	while IFS= read -r m; do [ -n "$m" ] && p_add "unresolved merge: $(printf '%s' "$m" | cut -d: -f1,2)"; done <<<"$G_OUT"
fi
finish "conflict markers" "no unresolved merge left"

# Upstream marks almost every skill hidden because Cursor lists them through a slash menu. The port
# lists the workflows and keeps the reference-only skills out of every prompt. The four reply and
# correction skills are the ones a user reaches by name from any turn, so a regression there is a
# skill that silently stops being offered.
P=""
hidden_list="$HIDDEN_SKILLS"
for d in "$PSTACK"/skills/principle-*/; do [ -d "$d" ] && hidden_list="$hidden_list $(basename "$d")"; done
nhidden=0
for s in $hidden_list; do
	f="$PSTACK/skills/$s/SKILL.md"
	need_file "$f" || continue
	v=$(fm_value "$f" disable-model-invocation)
	h=$(fm_value "$f" hide)
	if [ "$v" = true ] || [ "$h" = true ]; then nhidden=$((nhidden + 1)); else p_add "$f: must be hidden from the skill list"; fi
done
nvisible=0
for s in $VISIBLE_SKILLS; do
	f="$PSTACK/skills/$s/SKILL.md"
	need_file "$f" || continue
	v=$(fm_value "$f" disable-model-invocation)
	h=$(fm_value "$f" hide)
	if [ "$v" = true ] || [ "$h" = true ]; then p_add "$f: must stay visible in the skill list"; else nvisible=$((nvisible + 1)); fi
done
finish "visibility" "$nhidden hidden, $nvisible explicitly visible"

# ---- counts, catalog, versions ----------------------------------------------------------------

# The counts are generated by omp-port/sync-upstream.sh into marketplace.json. The two READMEs
# carry them by hand, so they rot silently unless the live tree is the judge. "principle" with no
# trailing s so it matches both "principles" and "principle leaves".
P=""
if counts=$(port_counts "$PSTACK") && read -r nskills nplays nprinc <<<"$counts" && [ -n "${nprinc:-}" ]; then
	pin7=$(cut -c1-7 omp-port/UPSTREAM) || p_add "inspection failure: omp-port/UPSTREAM is unreadable"
	nagents=$(find "$PSTACK/agents" -maxdepth 1 -type f -name '*.md' | wc -l | tr -d ' ') ||
		p_add "inspection failure: cannot list $PSTACK/agents"
	for f in README.md "$PSTACK/README.md" "$MARKET"; do
		need_file "$f" || continue
		for want in "$nskills skills" "$nplays playbooks" "$nprinc principle"; do
			file_has "$f" "$want" -F
			[ "$?" -eq 0 ] || p_add "$f wants \"$want\""
		done
	done
	file_has "$MARKET" "pstack at ${pin7:-?}." -F
	[ "$?" -eq 0 ] || p_add "$MARKET wants the pinned sha \"pstack at ${pin7:-?}.\""
	file_has "$MARKET" "${nagents:-?} agents." -F
	[ "$?" -eq 0 ] || p_add "$MARKET wants the installed agent count \"${nagents:-?} agents.\""
	gscan 'all measured|model-reliability floor|two agents' "$MARKET"
	st=$?
	if [ "$st" -ge 2 ]; then p_add "inspection failure: grep could not scan $MARKET: $G_ERR"
	elif [ "$st" -eq 0 ]; then
		while IFS= read -r l; do [ -n "$l" ] && p_add "$(printf '%s' "$l" | cut -d: -f1,2) carries a claim the port no longer makes"; done <<<"$G_OUT"
	fi
else
	p_add "inspection failure: could not count the live tree under $PSTACK"
	nskills="?" nplays="?" nprinc="?" pin7="?" nagents="?"
fi
finish "counts" "$nskills skills, $nplays playbooks, $nprinc principles, $nagents agents, pin $pin7"

# The port version is one stable counter, the package manifest's. The catalog carries the same
# string in three places and the sync script advances them together, so any disagreement is a
# half-applied release.
P=""
semver='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'
pv=$(jq -er '.version' "$PSTACK/package.json" 2>"$TMP/jq.err") || { p_add "inspection failure: $PSTACK/package.json has no readable version: $(tr '\n' ' ' <"$TMP/jq.err")"; pv=""; }
if [ -n "$pv" ]; then
	[[ $pv =~ $semver ]] || p_add "$PSTACK/package.json version '$pv' is not a plain MAJOR.MINOR.PATCH"
	cv=$(jq -r '[(.metadata.version // "missing"),
		([.plugins[] | select(.name == "pstack") | (.version // "missing")] | first // "missing"),
		([.plugins[] | select(.name == "fan-out") | (.version // "missing")] | first // "missing")] | join(" ")' \
		"$MARKET" 2>"$TMP/jq.err") || { p_add "inspection failure: $MARKET is not readable JSON: $(tr '\n' ' ' <"$TMP/jq.err")"; cv="$pv $pv $pv"; }
	read -r c_meta c_pstack c_fan <<<"$cv"
	[ "$c_meta" = "$pv" ] || p_add "$MARKET metadata.version is $c_meta, the package says $pv"
	[ "$c_pstack" = "$pv" ] || p_add "$MARKET pstack version is $c_pstack, the package says $pv"
	[ "$c_fan" = "$pv" ] || p_add "$MARKET fan-out version is $c_fan, the package says $pv"
fi
finish "versions" "package, catalog, and both plugin entries agree on ${pv:-?}"

# ---- the package surfaces ---------------------------------------------------------------------

# The port-owned paths are the one exception to "the build owns this tree", so their absence is
# the build silently dropping port behavior.
P=""
ownn=0
if owned=$(owned_paths); then
	while IFS= read -r p; do
		[ -n "$p" ] || continue
		ownn=$((ownn + 1))
		[ -e "$PSTACK/$p" ] || p_add "$p missing"
	done <<<"$owned"
	[ "$ownn" -gt 0 ] || p_add "no omp-port/owned.txt entries, the build has nothing to carry"
	want=$(printf '%s\n' $OWNED_ROOTS | sort)
	have=$(printf '%s\n' "$owned" | sed '/^$/d' | sort)
	[ "$want" = "$have" ] || p_add "omp-port/owned.txt must list exactly: $OWNED_ROOTS"
else
	p_add "inspection failure: omp-port/owned.txt could not be read"
fi
finish "owned" "$ownn owned path(s) present"

# Every pstack skill assumes the Cursor mechanics. omp-mechanics is where the omp ones live, and
# the injected reminder is the only thing that makes an agent read it.
P=""
need_file "$PSTACK/skills/omp-mechanics/SKILL.md"
need_file "$PSTACK/skills/pstack-omp/SKILL.md"
ext="$PSTACK/extensions/potetomode/index.js"
require "$ext" 'skill://omp-mechanics' -F "must point the reminder at skill://omp-mechanics"
require "$ext" 'skill://pstack-omp' -F "must point the reminder at skill://pstack-omp"
need_file "$PSTACK/extensions/potetomode/index.test.js"
# The manifest has to keep declaring the extension, and every declared file has to exist.
if exts=$(jq -er '.omp.extensions[]' "$PSTACK/package.json" 2>"$TMP/jq.err"); then
	while IFS= read -r e; do
		[ -n "$e" ] && { [ -f "$PSTACK/$e" ] || p_add "$PSTACK/package.json declares $e, which does not exist"; }
	done <<<"$exts"
else
	p_add "$PSTACK/package.json must declare omp.extensions: $(tr '\n' ' ' <"$TMP/jq.err")"
fi
finish "mechanics" "omp-mechanics and the adapter installed, extension declared and named in the reminder"

# The routing agents are the one agent surface the port adds. Source and installed copies have to
# agree byte for byte, hold exactly the settled name set, and select no model themselves.
P=""
src_names="" inst_extra=""
for f in "$PSTACK"/agents-extra/*.md; do
	[ -e "$f" ] || continue
	need_file "$f" || continue
	stem=$(basename "$f" .md)
	nm=$(fm_value "$f" name)
	st=$?
	if [ "$st" -ne 0 ]; then p_add "$f: no closed frontmatter block"; continue; fi
	[ "$nm" = "$stem" ] || p_add "$f: frontmatter name '$nm' is not its file name '$stem'"
	[ -n "$(fm_value "$f" description)" ] || p_add "$f: description missing"
	src_names="$src_names$nm"$'\n'
	fm_block "$f" | awk '/^(model|thinking[A-Za-z_-]*|blocking|spawns|tools)[ \t]*:/ { bad = 1 } END { exit bad }' ||
		p_add "$f: routing definitions must carry no model, thinking, blocking, spawns, or tools field"
	file_has "$f" 'skill://pstack-omp' -F
	[ "$?" -eq 0 ] || p_add "$f: body must direct the worker to skill://pstack-omp"
	file_has "$f" 'yield' -F
	[ "$?" -eq 0 ] || p_add "$f: body must finish through yield"
	inst="$PSTACK/agents/$stem.md"
	if [ ! -f "$inst" ]; then
		p_add "$inst: installed routing definition missing"
	else
		cmp -s "$f" "$inst"
		case "$?" in
		0) ;;
		1) p_add "$inst differs from its source $f" ;;
		*) p_add "inspection failure: cmp could not compare $f and $inst" ;;
		esac
	fi
done
src_sorted=$(printf '%s' "$src_names" | sed '/^$/d' | sort)
want_sorted=$(printf '%s\n' $ROUTING_AGENTS | sort)
[ "$src_sorted" = "$want_sorted" ] || p_add "$PSTACK/agents-extra declares [$(printf '%s' "$src_sorted" | tr '\n' ' ')], want exactly: $ROUTING_AGENTS"
for f in "$PSTACK"/agents/*.md; do
	[ -e "$f" ] || continue
	stem=$(basename "$f" .md)
	nm=$(fm_value "$f" name) || nm=""
	case " $ROUTING_AGENTS $COMPAT_AGENTS " in *" $stem "*) continue ;; esac
	case "$stem $nm" in
	pstack_* | *" pstack_"*) p_add "$f: not a routing agent in the settled set" ;;
	esac
done
for a in $COMPAT_AGENTS; do
	[ -f "$PSTACK/agents/$a.md" ] || p_add "$PSTACK/agents/$a.md: compatibility agent missing"
done
finish "routing agents" "exactly $(printf '%s\n' $ROUTING_AGENTS | wc -l | tr -d ' ') model-free definitions, installed copies identical"

# The licence travels with the code it covers, so each installable root has to carry the same
# notices as the repository root.
P=""
for pair in "LICENSE $PSTACK/LICENSE" "LICENSE $FANOUT/LICENSE" "THIRD_PARTY_NOTICES.md $PSTACK/THIRD_PARTY_NOTICES.md"; do
	set -- $pair
	if [ ! -f "$1" ] || [ ! -f "$2" ]; then
		p_add "$2: installed notice missing (or $1)"
		continue
	fi
	cmp -s "$1" "$2"
	case "$?" in
	0) ;;
	1) p_add "$2 differs from $1" ;;
	*) p_add "inspection failure: cmp could not compare $1 and $2" ;;
	esac
done
finish "notices" "installed notices match the root notices"

# The fan-out plugin is hand-written, never built from upstream, so the gate checks that it is whole.
P=""
need_file "$FANOUT/skills/fan-out/SKILL.md"
if jq -e '.plugins | map(.source) | all(. != null)' "$MARKET" >"$TMP/jq.out" 2>"$TMP/jq.err"; then
	for src in $(jq -r '.plugins[].source' "$MARKET"); do
		[ -d "$src" ] || p_add "$MARKET names source $src, which is not a directory"
	done
else
	p_add "inspection failure: $MARKET plugin sources are unreadable: $(tr '\n' ' ' <"$TMP/jq.err")"
fi
finish "plugin surfaces" "fan-out skill and every catalog source present"

# ---- reproducibility --------------------------------------------------------------------------

# The tree is build output. Rebuilding the pin has to reproduce it byte for byte outside the
# owned paths, otherwise someone hand-edited a file the next sync will overwrite. The build and the
# owned-path preparation are the same two functions the sync script installs from.
pin=$(tr -d '[:space:]' <"$PORT_DIR/UPSTREAM") || pin=""
canon_ok=no
P=""
if ! [[ $pin =~ ^[0-9a-f]{40}$ ]]; then
	p_add "omp-port/UPSTREAM must hold one full 40-hex sha, got '$pin'"
	finish "reproducible" ""
else
	scratch="$TMP/build"
	mkdir "$scratch" || p_add "inspection failure: cannot create $scratch"
	if ! ensure_canon "$pin" >"$TMP/build.log" 2>&1; then
		# A skipped reproduction would hide the one invariant this gate exists to prove behind a
		# green check, on a developer box as much as in CI.
		p_add "no clone at $CANON and cloning $UPSTREAM_URL failed, the build cannot be reproduced"
	elif ! { build_tree "$pin" "$scratch" && prepare_tree "$scratch"; } >>"$TMP/build.log" 2>&1; then
		p_add "build at ${pin:0:7} failed, rules or a patch no longer applies, or an owned path is missing"
		while IFS= read -r l; do [ -n "$l" ] && p_add "$l"; done < <(tail -n 5 "$TMP/build.log")
	else
		canon_ok=yes
		for d in skills agents; do
			diff -rq -x node_modules "$scratch/$d" "$PSTACK/$d" >"$TMP/diff.$d" 2>"$TMP/diff.$d.err"
			st=$?
			case "$st" in
			0) ;;
			1) while IFS= read -r l; do [ -n "$l" ] && p_add "$l"; done <"$TMP/diff.$d" ;;
			*) p_add "inspection failure: diff of $d exited $st: $(tr '\n' ' ' <"$TMP/diff.$d.err")" ;;
			esac
		done
	fi
	finish "reproducible" "tree equals the build at ${pin:0:7}"
fi

if [ "$canon_ok" = yes ]; then
	if untiered=$(untiered_slugs "$pin"); then
		untiered=$(printf '%s\n' "$untiered" | sed '/^$/d; s/^/  /')
		if [ -n "$untiered" ]; then
			report "untiered slugs" "REPORT  $(printf '%s\n' "$untiered" | wc -l | tr -d ' ') slug(s) only the catch-all rewrote"
			printf '%s\n' "$untiered"
		else
			report "untiered slugs" "REPORT  none, every slug has a tiered rule"
		fi
	else
		report "untiered slugs" "FAIL"
		violate "inspection failure: the catch-all rebuild at ${pin:0:7} failed"
	fi
else
	report "untiered slugs" "FAIL"
	violate "needs a reproducible build at ${pin:0:7}, which did not complete"
fi

if ! rm -rf "$TMP"; then
	fail=1
	echo "  inspection failure: could not remove the temporary directory $TMP"
fi
trap - EXIT

echo
if [ "$fail" -eq 0 ]; then echo "check-port: PASS"; else echo "check-port: FAIL"; fi
exit "$fail"
