# The substitution table, executable. Run as `sed -E -i -f omp-port/rules.sed <file>` on every
# text file of an upstream `pstack/{skills,agents}` export. Port-only file, never upstream.
#
# One rule per line, ordered, each with a `#` comment naming the Cursor mechanic and the omp
# mechanic it maps to. This file replaces PORTING.md's substitution table: the table is here now.
# Order is load-bearing in three places, each marked below.
#
# Prose the port adds on top of these rewrites lives in plugins/pstack/skills/omp-mechanics.
# Script changes live in omp-port/patches. Neither belongs here.

## 1. Whole-sentence rewrites, which must read raw upstream text before any token rule edits it.

# Cursor's multi-slug review panel -> one model per family, resolved at run time (backticked form).
s#`(claude|gpt|grok|gemini)-[a-z0-9.-]+`(, `(claude|gpt|grok|gemini)-[a-z0-9.-]+`)+#one model per distinct family `omp models` reports#g
# Same panel in the bare rule-file form, a `<role>: <slug>, <slug>` line with no backticks.
s#: (claude|gpt|grok|gemini)-[a-z0-9.-]+(, (claude|gpt|grok|gemini)-[a-z0-9.-]+)+$#: one model per distinct family omp models reports#
# Cursor names the judgment slug twice in one clause; omp names the capability once.
s#go to your strongest judgment model \(`claude-[a-z0-9.-]+`\)#go to your strongest judgment model#
# Cursor lists its spawn parameters inline. On omp the live task schema decides batch versus flat shape, background execution, and isolation, so each rewrite is conditional on it.
s#Spawn all N workers in one message with `subagent_type: generalPurpose`, `environment: "cloud"`, `run_in_background: true`, and the step 4 model, left unset for `auto` or `inherit-parent`\. Use `environment: "local"` only when the worker needs access to something on the user's computer\.#Spawn all N workers together through `skill://pstack-omp`, each on the step 4 route, in the batch or flat shape the live `task` schema accepts. Add `isolated: true` only when the schema exposes it and the isolation gate in `skill://omp-mechanics` passes. A worker that needs this machine's installed tools, simulators, or local credentials runs in the shared checkout instead.#
s#Spawn all N subagents in one message with `run_in_background: true`, each with#Spawn all N subagents together through `skill://pstack-omp`, in the batch or flat shape the live `task` schema accepts, each with#
s#One message, three `Task` calls, `subagent_type: generalPurpose`, agent mode \(`readonly: false`\)\.#Spawn the three reviewers together through `skill://pstack-omp`, in the batch or flat shape the live `task` schema accepts, each on its own exact agent route below with full tools per spawn.#
# Cursor reads the playbook from trunk because it is vendored there; omp reads the install.
s#Read these from trunk at program start\. Re-read them at every tick\.#Read these at program start and re-read them at every tick. The loaded skill files are authoritative, not a remote ref.#
# Cursor's rule file is the artifact step 5 writes; omp's is the keyed task.agentModelOverrides map in the effective user settings.
s#Write `~/\.cursor/rules/pstack-models\.mdc`, an always-applied rule that sets pstack's model per role\.#Write `task.agentModelOverrides` in the effective user settings, the keyed override map that sets pstack's model per routing agent. The chat model stays the operator's choice, made with `/model`, and setup never changes it. `skill://omp-mechanics/references/setup-pstack-config.md` holds the routing contract and the file shape.#
s|Write `~/\.cursor/rules/pstack-models\.mdc` with `alwaysApply: true`, a `# budget` line with the chosen label and its target effort, and one line per role, using the same labels poteto-mode uses\. Overwrite the whole file so re-runs stay idempotent\. Shape:|Write only the `task.agentModelOverrides` keys this skill owns, one concrete selector per key, and preserve every other entry. The budget is a label you report plus a `:thinking` suffix on each selector, not a stored line. `skill://omp-mechanics/references/setup-pstack-config.md` holds the owned keys and the file shape. The block below is the role-to-capability table and not the file format. Shape:|

## 2. Model slugs. Tiered by capability first, then a catch-all for anything upstream adds later.

# Cursor's strongest reasoning slug -> the judgment capability the operator binds.
s#`claude-fable-[0-9.-]+(-(thinking-)?[a-z]+)?`#your strongest judgment model#g
# Cursor's second reasoning family -> the same judgment capability.
s#`claude-opus-[0-9.-]+(-(thinking-)?[a-z]+)?`#your strongest judgment model#g
# Cursor's instruction-following slug -> the instruction-following capability.
s#`gpt-[0-9.]+-sol-[a-z]+`#your strongest instruction-following model#g
# Cursor's fast coding slug, with or without an effort suffix -> the fast code capability.
s#`grok-[0-9.]+-([a-z]+-)?fast(-[a-z]+)?`#your fast code model#g
# The same family under Cursor's provider prefix, effort token in the middle.
s#`cursor-grok-[0-9.]+-([a-z]+-)?fast`#your fast code model#g
# The same tiers where the rule-file example writes a role value with no backticks. Anchored to
# the end of a `<role>: <slug>` line, which is the only place upstream writes a bare slug.
s#: claude-(fable|opus)-[0-9.-]+(-(thinking-)?[a-z]+)?$#: your strongest judgment model#
s#: gpt-[0-9.]+-sol-[a-z]+$#: your strongest instruction-following model#
s#: grok-[0-9.]+-([a-z]+-)?fast(-[a-z]+)?$#: your fast code model#
# Catch-all for a slug no tier above knows. Two hyphen groups required, so an illustrative
# `gpt-4` rename example is not a prescription and survives. omp-port reports what this rewrote.
s#`(claude|gpt|grok|gemini|opus)-[a-z0-9.]+-[a-z0-9.-]+`#your configured model for this role#g

## 3. The task wire. Cursor's Task parameters -> omp's task tool fields.

# `subagent_type: "X"` (Cursor's agent selector) -> omp's `agent` field.
s#`subagent_type: "([^"]+)"`#`agent`: `\1`#g
s#`subagent_type: generalPurpose`#`agent`: `task` (omp's general-purpose bundled agent)#g
s#`subagent_type`: `generalPurpose`#`agent`: `task` (omp's general-purpose bundled agent)#g
s#`subagent_type`#`agent`#g
s#subagent_type#agent#g
# `generalPurpose` (Cursor's built-in general agent) -> `task`, omp's bundled general agent.
s#`generalPurpose`#`task` (omp's general-purpose bundled agent)#g
s#generalPurpose#`task` (omp's general-purpose bundled agent)#g
# Cursor's one-parameter background spawn -> omp batches every spawn in one tasks[] array.
s#\*\*Defaults for every `Task` call\.\*\* `run_in_background: true`,#**Defaults for every `Task` call.** One `task` call with all items in `tasks[]`, batched in parallel,#
s#`run_in_background: true`#one `task` call with all items in `tasks[]` (batched in parallel)#g
# Cursor's readonly spawn mode -> posture in the brief, because omp's task wire has no such field.
s#`readonly`: `true`#read-only posture. The brief grants only Glob, Grep, and Read, and forbids writes#g
s#agent mode \(readonly strips MCP\)#full tools per spawn#g
s#agent mode \(`readonly: false`\)#full tools per spawn#g
s#with `readonly: false` \(agent mode\)\. \*\*Do not use readonly/Ask mode\.\*\* It strips MCP access, which disables#with full tools per spawn. There is no `readonly` field and no Ask mode on omp's task wire, so nothing strips MCP access, which would otherwise disable#
s#`readonly`: `false` \(agent mode\)\.#Full tools per spawn.#g
s#, and readonly strips MCPs\.#. omp's task wire has no `readonly` field, so nothing strips them.#g
s#Readonly/Ask mode strips MCPs and defeats that\.#There is no such mode on omp's task wire, so nothing strips MCPs.#
s#Spawn one readonly judge subagent on that model\.#Spawn one judge subagent whose brief grants read tools only.#
s#readonly: true#read-only posture, granted in the brief#g
# Cursor's ask tool -> `ask`, omp's tool name.
s#`AskQuestion`#`ask`#g
s#AskQuestion#`ask`#g
s#`allow_multiple: true`#`multi: true`#g
# Cursor's per-role model rule file -> the keyed override map in omp's config.
s#`~/\.cursor/rules/pstack-models\.mdc`#`task.agentModelOverrides`#g
s#the `pstack-models\.mdc` rule#`task.agentModelOverrides`#g
# Cursor's Task-spawn slug enumeration and hypothetical models API -> `omp models`.
s#Enumerate the model slugs you can pass to a `Task` subagent in this session\. That is the dependable source\. If Cursor also exposes a models API or CLI that lists the user's entitled models, prefer it for completeness\.#Run `omp models` to list the models configured on this machine. That is the dependable source.#
# Cursor's blocking watch mode -> the same hazard, named with omp's polling and blocking primitives too.
s#Reaching for `drive` inside a phase agent stops that agent finishing its turn\.#Blocking on `drive`, or polling a job in a loop with `read proc://`, inside a phase agent stops that agent finishing its turn.#
# Cursor's Task `model` argument -> omp has no per-call field, only the keyed override map.
s#\(omit Task `model`\)#(remove that agent's key from `task.agentModelOverrides`)#g
s#For a model race, name each arm's model up front\.#For a model race, run the arms on distinct `pstack_panel_<n>` agents, each with its own configured selector.#
# Cursor matches reasoning level and fast or standard speed per spawn; omp has only the gated per-item `effort` field and no speed lever.
s#Pick each subagent's reasoning level and fast or standard speed for the job, per the Subagents section( of the \*\*poteto-mode\*\* skill)?\.#Pick each subagent's reasoning `effort` for the job when the live `task` schema exposes it, per the Subagents section\1.#g
# Cursor writes an always-applied rule file; omp writes only the owned task.agentModelOverrides keys.
s#Tell the user the rule was written and that it applies to new sessions\.#Tell the user which entries were written and that they apply to new sessions.#
s#Per-role lines in the `/setup-pstack` rule override#Per-role entries written by `/setup-pstack` override#g
/^alwaysApply: true$/d
# Cursor agent frontmatter `is_background` -> omp does not model it.
/^is_background: true$/d
# The router and its agent must name the omp levers file themselves, not only the pin reminder,
# so an unpinned read of skill://poteto-mode or a spawned poteto-agent still finds it.
s|^## Non-negotiables$|## Non-negotiables\n\n**Read `skill://omp-mechanics` right after this file.** It holds the omp-specific levers every step below assumes.|
s#Reads the `poteto-mode` skill's `SKILL.md` in full before any work, including its inline Principles index\.#Reads the `poteto-mode` skill's `SKILL.md` in full before any work, including its inline Principles index, then `skill://omp-mechanics`.#
# Cursor derives a skill's registry name from a display title; omp uses the directory slug, and
# skill://<name> and /skill:<name> match the name exactly, so a title would make the skill unreachable.
s#^name: Poteto Mode$#name: poteto-mode#
s#^name: Make Bot UI$#name: make-bot-ui#

## 4. Cloud agents. Cursor runs them on its own VMs; omp runs isolated subagents on this machine.

s#`environment: "cloud"`#`isolated: true` when the live schema exposes it#g
s#the full Task schema including `environment`#the full Task schema including `isolated`#g
# `cloud_base_branch` is not accepted by omp's task tool; a worktree on that base is the answer.
s#When a worker must start from a non-default pushed branch, pass `cloud_base_branch`\.#When a worker must start from a non-default base, create its `git worktree` on that base first and point the worker at that path.#
s#One Cursor cloud agent#One isolated subagent (a private worktree, per `skill://pstack-omp`)#g
s#each a Cursor cloud agent#an isolated subagent (a private worktree, per `skill://pstack-omp`)#g
s#Each owner is a Cursor cloud agent#Each owner is an isolated subagent (a private worktree, per `skill://pstack-omp`)#g
s#Cloud agents cannot read the local store, so their briefs inline what they need or point at repo paths\.#An isolated worker runs on this machine in its own worktree with no conversation history, so its brief inlines what it needs or points at absolute paths.#
# Cursor's cloud dashboard -> omp's `history://` and `proc://` reads.
s#the cloud agent's status in the Cursor dashboard#agent state from `read history://` (registered agents) and `read proc://` (visible jobs and running agents)#
# Cursor's cloud PR tooling defaults to draft; omp's github tool defaults to ready.
s#A built-in PR tool can default to draft, so set `draft: false` on every creation call through it\.#omp's `github` tool opens a ready PR from `op: "pr_create"` unless you pass `draft: true`, so leave that flag off.#
s#Each live lane runs on its own cloud VM at the PR head\.#Each live lane runs in its own subagent at the PR head, in a private worktree. Use `isolated: true` when the live schema exposes it, and an explicit `git worktree` otherwise.#
s#Fan out N parallel cloud workers\.#Fan out N parallel workers.#
s#N is total workers, not the cloud concurrency limit\.#N is total workers. `task.maxConcurrency` caps how many run at once.#
# Cursor hands out a cloud-agent URL; omp's prior-run handles are internal URIs.
s#cloud-agent URL#prior agent's `history://<id>` or `agent://<id>`#g
# Cursor's local-versus-cloud split -> shared parent checkout versus a private worktree.
s#cloud spawns#isolated spawns#g
s#its spawn budget with the cloud default and the local exception list#its spawn budget with the isolated default and the shared-checkout exception list#
s#Chain rebases run in cloud\. A local rebase at this scale takes the laptop down\.#Chain rebases run in an isolated subagent with its own worktree, never in the parent checkout.#
s#After a Cursor restart: local agents are dead, cloud work is not\.#After an omp restart, a resumed session rebuilds its subagents as parked rows that a `write` to `agent://<returned-id>` can revive. Isolated children cannot be cold-revived after a host restart, so reconcile their durable branch, PR, and `history://<id>` transcript and dispatch replacement work.#
s#reattach cloud work by PR and branch rather than agent id#reattach pushed work by PR and branch rather than agent id#
s#a Cursor restart#an omp restart#g
s#cloud agent#isolated subagent#g
s#Cloud agent#Isolated subagent#g

## 5. Wake mechanisms. Cursor's `/loop` builtin and cloud sleeper -> omp's `/loop` in session and an authenticated integration out of session.

s#Drive a long or stubborn hunt with Cursor's `/loop` command\.#Drive a long or stubborn hunt with omp's `/loop`. Inspect its live help for the grammar and cadence it accepts before prescribing either, and state the exit condition as a shell command the loop can test.#
s#Pick the wake mechanism using Cursor's `/loop` command \(a built-in, not a pstack skill\)\.#Pick the wake mechanism. In session, omp's `/loop` re-submits a prompt, and its live help decides the grammar and cadence. A wake that must land out of session needs an authenticated external trigger: launchd on macOS, or an available systemd user timer or cron on Linux, calling an explicit CLI or RPC entry point (`prompt`, `steer`, or `follow_up`) or an extension. A named `bash` service only observes work while the session exists and is not a scheduler.#
s#A local root arms each tick as a real terminal `/loop`\. The loop uses a monitored-shell 30-minute sleep and emits an output-notification sentinel\.#A root in session arms each tick with omp's `/loop`, after reading its live help for the grammar and cadence it accepts.#
s#A cloud root uses the existing cloud-sleeper wake chain instead\.#A wake that must land out of session needs an authenticated external trigger: launchd on macOS, or an available systemd user timer or cron on Linux, calling an explicit CLI or RPC entry point.#
s#In a local session, a real terminal `/loop`\. In a cloud root, a cloud-sleeper wake chain\.#In session, omp's `/loop`, with its grammar and cadence read from its live help. A wake that must land out of session needs an authenticated external trigger such as launchd on macOS, or a systemd user timer or cron on Linux.#
s#Run `drive` and `background` under `/loop` in dynamic mode\.#Run `drive` and `background` under omp's `/loop` when its live help shows it fits the cadence you need, or hold them in a named `bash` service that observes only while the session exists. A wake that must land out of session needs an authenticated external trigger calling an explicit CLI or RPC entry point.#
s#Hold the watch under `/loop` in dynamic mode\.#Hold the watch under omp's `/loop` when its live help shows it fits the cadence you need, or in a named `bash` service that observes only while the session exists. A wake that must land out of session needs an authenticated external trigger calling an explicit CLI or RPC entry point.#
s#under `/loop` until it reports `COMPLETE` at the ceiling\.#under omp's `/loop` when its live help shows it fits the cadence you need, or in a named `bash` service that observes only while the session exists, until it reports `COMPLETE` at the ceiling. A wake that must land out of session needs an authenticated external trigger: launchd on macOS, or an available systemd user timer or cron on Linux, calling an explicit CLI or RPC entry point (`prompt`, `steer`, `follow_up`) or an extension.#
s#`/loop` per component until the diff is zero\.#Hold a named `bash` service per component until the diff is zero, or re-check under omp's `/loop`.#
s#a frontier watcher wake \(arm it via the loop skill, with a long heartbeat fallback\)#a frontier watcher wake (a named `bash` service while the session exists, with a long fallback heartbeat)#
s#"/loop until X"#"run until X"#g

## 6. cursor-team-kit. Cursor's companion plugin -> omp's built-in tools.

# `/deslop` -> the `unslop` skill plus `omp cleanse` for diagnostics.
s#the `deslop` skill from the `cursor-team-kit` plugin \(`/deslop`\)#the `unslop` skill (`skill://unslop`) plus `omp cleanse --all` for diagnostics#g
s#Run `/deslop` from `cursor-team-kit` over the diff before commit\.#Run the `unslop` skill (`skill://unslop`) plus `omp cleanse --all` over the diff before commit. A bare `omp cleanse` opens an interactive picker and blocks.#
s#`/deslop`#the `unslop` skill (`skill://unslop`) plus `omp cleanse --all`#g
# `control-ui` / `control-cli` -> `browser`, `computer`, and `bash`.
s#`control-ui` or `control-cli` runtime verification \(from `cursor-team-kit`\)#`browser` or `computer` for UIs, or `bash` for CLIs and TUIs#
s#\(`control-cli` or `control-ui` from `cursor-team-kit` as the change demands\)#(`browser` or `computer` for UIs, `bash` for CLIs and TUIs, as the change demands)#
s#\(`control-ui` or `control-cli` from `cursor-team-kit` as the change demands\)#(`browser` or `computer` for UIs, `bash` for CLIs and TUIs, as the change demands)#
s#Drive through `control-ui` or `control-cli` from `cursor-team-kit`\.#Drive through `browser` or `computer` for UIs, and `bash` for CLIs and TUIs.#
s#Browser, Electron, and web UIs use `control-ui` from `cursor-team-kit`\. CLIs and TUIs use `control-cli` from `cursor-team-kit`\.#Browser, Electron, and web UIs use the `browser` eval prelude, and native desktop UIs use `computer`. Both are code in an `eval` cell and not tools. CLIs and TUIs use `bash`, with a named service for a long-lived process.#
s#`cursor-team-kit` publishes `control-cli` \(CLIs and TUIs\) and `control-ui` \(browser / Electron / web UIs\)\.#omp provides the levers directly. `bash` drives CLIs and TUIs, the `browser` eval prelude drives browser, Electron, and web UIs over CDP, and the `computer` prelude drives native desktop. Both preludes are code in an `eval` cell and neither is a tool with its own schema.#
s#\*\*Control skill\.\*\* Pick it by surface\.#**Control surface.** Pick it by surface.#
s#through the control skill's commands#through the control surface's own calls#
s#`control-ui`#the `browser` eval prelude#g
s#`control-cli`#`bash`#g
s#`cursor-team-kit`#omp's built-in tools#g
s#cursor-team-kit#omp's built-in tools#g

## 7. create-skill. Cursor's SKILL.md authoring builtin -> pstack's own authoring playbook.

# The playbook cannot route to itself, so its step 1 states the omp authoring path directly.
s#^1\. Use the \*\*create-skill\*\* skill \(Cursor's built-in for authoring SKILL\.md files\)\.$#1. Write the SKILL.md yourself with `write` or `edit`. omp's `manage_skill` writes only under `~/.omp/agent/managed-skills` and never touches a user-authored skill. Give it YAML frontmatter with `name` matching its directory, a `description` naming what the skill does and when to reach for it, and `disable-model-invocation: true` so it stays out of the per-turn index.#
s#the \*\*create-skill\*\* skill \(Cursor's built-in for authoring SKILL\.md files\)#the **authoring-a-skill** playbook (`playbooks/authoring-a-skill.md`)#g
s#A `create-skill`-style#An `authoring-a-skill`-style#g
s#Cursor's built-in `create-skill` skill#the `authoring-a-skill` playbook#g
s#Cursor's built-in `create-skill`#the `authoring-a-skill` playbook#g
s#`create-skill`'s#the `authoring-a-skill` playbook's#g
s#new skill via create-skill:#new skill via authoring-a-skill:#g
s#draft a new skill via create-skill#draft a new skill via the authoring-a-skill playbook#g
s#via create-skill \+ unslop#via the authoring-a-skill playbook + unslop#g
s#`create-skill`#the `authoring-a-skill` playbook#g

## 8. Transcripts. Cursor's per-project transcript directory -> omp's session store.

s#`~/\.cursor/projects/<slug>/agent-transcripts/<uuid>/<uuid>\.jsonl`#the session store, by default `~/.omp/agent/sessions/<encoded-cwd>/<timestamp>_<session-id>.jsonl`#
s#where `<slug>` is the workspace path with the leading slash dropped and each "/" turned into "-" \(so `/Users/you/proj` becomes `Users-you-proj`\)#where `<encoded-cwd>` is the cwd with $HOME stripped and each "/" turned into "-" (so `~/proj` becomes `-proj`)#
s#Every line is one chat message\.#Every line is one JSON object. The first is a fixed-width `type:title` slot, the second a `type:session` header, and the rest messages whose roles are camelCase (`toolResult`, not `tool_result`).#
s#the active workspace's `agent-transcripts/` directory#the session transcript tree `~/.omp/agent/sessions/<encoded-cwd>/*.jsonl`, with subagent sidecars at `<session-stem>/<AgentId>.jsonl`#g
s#the workspace's `agent-transcripts/` directory#the session transcript tree `~/.omp/agent/sessions/<encoded-cwd>/*.jsonl`, with subagent sidecars at `<session-stem>/<AgentId>.jsonl`#g
s#local transcripts under `agent-transcripts/`#local transcripts under `~/.omp/agent/sessions/<encoded-cwd>/`#
s#`~/\.cursor/projects/\*/`#sibling `~/.omp/agent/sessions/<other-cwd>/` buckets#g
s#<agent-transcripts>#~/.omp/agent/sessions/<encoded-cwd>#g
# Cursor kept three historical transcript layouts; omp writes one.
s#That covers the legacy flat \(`<id>\.jsonl`\), current nested \(`<id>/<id>\.jsonl`\), and subagent \(`<parent>/subagents/<child>\.jsonl`\) layouts\.#omp writes one layout: a flat `<timestamp>_<session-id>.jsonl` per session in the bucket, with `<AgentId>.jsonl` sidecars in the sibling directory named for that stem.#
s#For each candidate, read the first JSONL line\. Take the file whose `message\.content\[0\]\.text` contains the conversation's opening user prompt\.#The first line of an omp transcript is a fixed-width `type:title` slot and the second a `type:session` header, neither of them a message. Take the file whose first `type:message` line with `role:user` contains the conversation's opening user prompt.#
# Cursor's skill roots -> omp's workspace, user, and plugin skill roots.
s#~/\.cursor/skills/#~/.omp/agent/skills/#g
s#\.cursor/skills/#.omp/skills/#g
s#, or plugin-installed paths under `~/\.cursor/plugins/`#, or plugin-installed skills through `skill://<name>`#g
# Cursor's worktree path convention -> whatever path the local tool manages.
s#misses one that lives at `\.cursor/worktrees/myrepo/x`#misses one that lives at a tool-managed path like `.worktrees/myrepo/x`#
# Cursor's pinned-chat sidebar -> omp's live roster plus the session store.
s#The pinned and active chats are the real artifact \(principle-prove-it-works\)\. Get that set from the user or sidebar and cross-check every candidate\. The lever has marked `safe` a worktree the user had pinned, so the pinned set wins\.#The live omp sessions are the real artifact (principle-prove-it-works). Get that set from `read history://` (registered agents) and `read proc://` (visible jobs and running agents), plus the session store resolved per `skill://omp-mechanics/references/session-store-on-omp.md`, confirm it with the user, and cross-check every candidate. The lever has marked `safe` a worktree a live session still owned, so the live set wins.#
s#report whether the chat is pinned or ongoing and which worktrees it touches#report whether the session is still live and which worktrees it touches#
s#A pinned chat spawns arena and repro trees into sibling worktrees via background subagents, and those are in use even when their names never hit the sidebar\.#A live session spawns arena and repro trees into sibling worktrees via background subagents, and those are in use even when `read history://` never names them.#
# Cursor exposes enabled MCP servers as a directory; omp lists them in one config file.
s#Before spawning investigators, list the available MCPs from the Cursor environment\. Use the available-tools map when present\. Otherwise inspect the `mcps/` directory Cursor exposes for enabled MCP servers\.#Before spawning investigators, list the available MCPs from the live tool inventory and `/mcp list`. For servers that are not connected, follow the MCP discovery procedure in `skill://omp-mechanics`. The default user `mcp.json` is one source among several.#
# Cursor resumes an idle agent to reach it; omp messages it and leaves it running.
s#Agents are spawned, resumed, and drained only through the Task tool\.#Agents are spawned and drained only through the Task tool, and an idle one is revived only by a `write` to `agent://<returned-id>`.#
# Bugbot is a Cursor product, so the rubric names what plays its part on omp.
s#^Use this reference when the Babysit playbook \(`\.\./playbooks/babysit\.md`\) handles Bugbot or review-automation comments\.#Use this reference when the Babysit playbook (`../playbooks/babysit.md`) handles Bugbot or review-automation comments. Bugbot is Cursor's hosted review product, so without it this rubric applies to whatever review bot posts on your PRs, including omp's own `security-reviewer`.#
# Net for any Cursor home path a later upstream commit introduces.
s#~/\.cursor/#~/.omp/#g

## 9. Install paths. pstack is vendored in Cursor's monorepo and installed as a plugin on omp.
## Order is load-bearing: the trunk-read rewrites and the checklist append run before the
## generic pstack/skills/ rewrite, which is guarded so it cannot re-match its own output.

s#re-read this playbook from trunk with `git show origin/main:pstack/skills/#re-read this playbook with `skill://#g
s#Re-read the execution playbook from trunk( and the armed /goal)?#Re-read the execution playbook through its `skill://poteto-mode/playbooks/` URI\1#g
s#Each tick re-reads this playbook from trunk#Each tick re-reads this playbook through its `skill://poteto-mode/playbooks/` URI#g
s#re-reads both playbooks from trunk#re-reads both playbooks through their `skill://poteto-mode/playbooks/` URIs#g
s#`git show origin/main:<control skill path>`#the omp doc for the control surface, such as `omp://tools/browser.md`, remembering that `browser` and `computer` are eval preludes rather than tools#
s#`git show origin/main:pstack/skills/#`skill://#g
s#`node pstack/skills/poteto-mode/scripts/check-plan\.mjs <plan\.md>`#`node <poteto-mode-dir>/scripts/check-plan.mjs <plan.md>`, after resolving `<poteto-mode-dir>` with `realpath skill://poteto-mode` as its own command#
s#([^/])pstack/skills/#\1skill://#g
# Cursor's npm scope for skill tooling -> the port's own scope.
s#@cursor-skill/#@omp-skill/#g
# Cursor auto-attaches a skill on a file-glob match; omp carries `globs` as metadata only.
s#^paths: \[#globs: [#

## 10. User-facing skill commands. Cursor's slash menu runs a skill as `/<name>`; omp runs a shipped skill as `/skill:<name>`.
## `/poteto-mode` is the extension's own alias and stays, as do the runtime commands (`/model`, `/marketplace`, `/loop`, `/goal`).
## The left boundary refuses a letter, `/`, `.`, `:`, `~`, `$`, or `-` before the slash, so a URL, a path, or a `skill://` URI is not a command.
## The rule runs twice because each match consumes its right boundary, so two commands one space apart need a second pass.

s#(^|[^[:alnum:]_/.:~$-])/(architect|arena|automate-me|benchmark-checklist|blast-radius|bro|correct|create-verification-skill|figure-it-out|how|in-your-own-words|interrogate|ketchup|maintain-verification-skill|make-bot-ui|no-comments|poteto-help|recall|reflect|setup-pstack|sharpen|show-me-your-work|swarm|tdd|teach|technical-writing|typescript-best-practices|unslop|why)([^[:alnum:]_/-]|$)#\1/skill:\2\3#g
s#(^|[^[:alnum:]_/.:~$-])/(architect|arena|automate-me|benchmark-checklist|blast-radius|bro|correct|create-verification-skill|figure-it-out|how|in-your-own-words|interrogate|ketchup|maintain-verification-skill|make-bot-ui|no-comments|poteto-help|recall|reflect|setup-pstack|sharpen|show-me-your-work|swarm|tdd|teach|technical-writing|typescript-best-practices|unslop|why)([^[:alnum:]_/-]|$)#\1/skill:\2\3#g

## Dynamic skill names the shipped list cannot name. A personal mode is authored as `<handle>-mode` and a generated verification skill as `verify-<app>`.
## omp registers both as `/skill:<name>`, and the personal-mode procedure registers no extension command of its own. The boundaries match the rule above.
s#(^|[^[:alnum:]_/.:~$-])/(<handle>-mode|verify-<app>)([^[:alnum:]_/-]|$)#\1/skill:\2\3#g
s#(^|[^[:alnum:]_/.:~$-])/(<handle>-mode|verify-<app>)([^[:alnum:]_/-]|$)#\1/skill:\2\3#g
