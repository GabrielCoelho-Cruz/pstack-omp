---
name: omp-mechanics
description: The omp-specific levers for every pstack skill. Read it after `skill://poteto-mode`, and again whenever a pstack skill or playbook tells you to spawn a subagent, pick a model, drive a surface, or wake yourself later. Every entry names the upstream step it amends and the omp instruction that replaces or extends it.
disable-model-invocation: true
---

# omp mechanics

pstack's skills are mirrored from Cursor and their mechanics are rewritten for omp by
`omp-port/rules.sed`. That rewrite is a token substitution, so anything omp does differently in
kind rather than in name lands here instead. Each section names a skill or playbook and amends a
numbered step.

The port preserves its runtime adapters through `omp-port/owned.txt`. Read
`skill://pstack-omp` before dispatch; its live-tool contract overrides task-specific examples here and in imported references. These examples apply only when the corresponding surface is exposed, not to vibe workers.

## Every task call

These hold for every `task` spawn any pstack skill asks for. `references/task-wire-on-omp.md` holds
the item shape, the per-agent lever table, the isolation lifecycle, and the budgets.

- **No `model` field.** The `task` tool takes no per-call model. A model is routed by exact agent
  name: `task.agentModelOverrides[agentName] = concreteSelector`. pstack ships six model-free agents,
  `pstack_fast`, `pstack_judgment`, and `pstack_panel_1` to `pstack_panel_4`, and a routed skill
  selects one through the item's `agent` field. A settings override beats the agent file's
  frontmatter, which beats the parent or configured task fallback, so an agent with no entry runs on
  the parent's model. That is the correct default and needs no configuration. A choice to inherit
  removes the key. The key set, value format, and panel rules live in
  `references/setup-pstack-config.md`. Service-tier, prewalk, and advisor records are the
  operator's, not pstack's.
- **Required fields.** Every item needs `task` and `solutionSpace`. `solutionSpace` says how open the
  child's problem is, such as `one fix: rename, names given`. Work volume does not widen it. `name`
  and `agent` are optional, and omitting `agent` runs the default worker. A named item needs a
  unique `name`, compared case-insensitively.
- **No `readonly` field.** A read-only worker is posture carried in the brief, never a wire field.
  Name the tools the worker may use and forbid writes. The per-item `tools` field exposes only
  kernel tools the parent defined in an `eval` cell with `@tool` or `tool(fn, …)`, gated by
  `eval.tools.enabled`, so it is not a tool grant. The one per-spawn restriction omp enforces is
  `tools` in an agent's frontmatter, which binds to an agent definition and not to a task call. An
  explicit list gains `yield`, which a child finishes through, and gains `wait` when it contains
  `task` or `bash`. The shipped routing agents declare no `tools`, so they keep the runtime's normal
  tool set, MCPs included, and are not read-only sandboxes.
- **Batch, flat, and background.** `task.batch` controls the shape. With it on, independent spawns
  go in one call as `{ context, tasks[] }`, and `context` is required and rendered into every
  spawn's system prompt, so the shared contract goes there once. With it off, a call is one flat
  spawn, `tasks` and `context` are rejected, shared background goes in a `local://` file, and all
  independent spawns are started before any wait. `async.enabled` controls ordinary background
  execution: on, a spawn returns job and agent IDs and its result auto-delivers; off, the call
  blocks. A custom agent with `blocking: true` runs inline in either case.
- **Three different limits.** `task.maxConcurrency` bounds task's session-wide semaphore, which is
  resized live from the setting and covers every task spawn, inline or background, across calls.
  Each eval `workpool()` separately caps its own live workers at that same setting. Eval's
  `agent()` takes no concurrency slot and instead counts against the session-wide `async.maxJobs`
  cap that every background job shares, including async `bash`, async `task`, pools, and nested
  jobs. Unlike a task item, eval's `agent()` takes `apply` and `merge`.
- **Eval barriers.** `agent()` returns a handle and eval's `wait(handles)` returns results in input
  order, which is a different thing from the zero-argument `wait` tool. A pool's name is its
  aggregate job id, and there is no `pool.wait()`. Leave eval, let results auto-deliver, and call the
  `wait` tool only when blocked.
- **Leave `effort` unset.** The per-spawn `effort` field (`"lo"`, `"med"`, `"hi"`) reaches the
  schema only while `task.enableEffort` is true, and it overrides the route's configured thinking:
  OMP maps it to the model's own range, so `hi` is the model's top level (`max` on current Claude
  models). Routes carry their thinking in the `task.agentModelOverrides` selector suffix instead.
  Set `effort` only on the user's request or once after a route's level demonstrably failed, and
  report the resolved level. `task.maxEffort` caps it when enabled.
- **`isolated: true` is opt-in and gated.** It gives the worker its own worktree, and it reaches the
  tool only while `task.isolation.enabled` is true **and** plan mode is disabled, so check both
  (`omp config list | grep task.isolation`). Without the flag a worker shares the parent checkout,
  so switching branches there is not isolation. The parent must run from inside a git checkout. The
  worktree is a clone of the current checkout, uncommitted work included, not a checkout of `HEAD`.
  `task.isolation.apply`, default true, lands its changes automatically. Turn it off when the
  coordinator must review each patch first. When the gate is off, give each worker its own
  `git worktree` or its own `/tmp/<slug>/worker-<n>/` directory instead. Cursor's `environment` and
  cloud-base-branch arguments are rejected outright.
- **In plan mode a spawn can only read.** Every subagent is restricted to `read`, `grep`, `glob`,
  and `web_search`, and `isolated` and `tools` are rejected. A fan-out whose workers edit, or whose
  workers nest, runs outside plan mode.
- **A subagent starts blank.** No conversation history, and an isolated one cannot see its
  siblings. It does inherit the workspace tree, the skills, the context files, and the parent's
  `local://` root, so a large shared payload goes to `local://<name>.md` and the brief names that
  path. Otherwise inline what it needs or point at absolute paths.
- **Yield first.** End every brief with a yield-first line. A child must finish through the `yield`
  tool with its result or its failure and write no text outside that call. Thinking models can
  default to answering in prose, which costs up to three reminder prompts and then a `SYSTEM
  WARNING` with no structured output. Historical observation, one model and one batch width, not a
  rate: 13 of 20 workers yielded without the line and 20 of 20 with it.
- **Budgets stop a long worker.** `task.softRequestBudget`, default 200 assistant requests, warns
  on crossing and force-stops the run at 1.5 times the budget. `task.maxRuntimeMs` is a hard
  per-spawn wall clock in milliseconds, 0 disabled. Brief a long worker to yield partial findings.
- **Reaching a running agent.** `read history://` lists registered agents and transcripts. `read
  proc://` lists visible jobs, running agents that have no job row, and project services, and one
  `read proc://<returned-job-id>` reads a status without consuming its automatic delivery. Messages
  self-deliver, and there is no inbox-drain tool. To message an agent, `write` to
  `agent://<returned-id>`; use `agent://all` only for an intentional broadcast. An `idle` agent
  parks after `task.agentIdleTtlMs`, and a direct message revives a parked agent in-process. A
  kept-alive isolated agent retains its workspace through idle and parked states and revives the same
  way. Releasing it captures the final changes and cleans the workspace, and a hard abort is
  terminal. After a host restart isolated children cannot be cold-revived: reconcile the durable
  artifacts and dispatch replacement work. The `wait` tool takes no arguments and returns on the
  first owned result, message, or interrupt, so use it only when blocked and never inside an agent
  that still owes its parent a turn. Account for every required result separately. A finished
  agent's output is `agent://<id>`, a nested child's is `agent://Parent.Child`, structured data is
  `agent://Parent.Child/reports/0/data`, and the transcript is `history://<id>`.
- **Proving a claim.** Run a finite check with ordinary `bash`. Use `async: true` only when exposed,
  keep in mind that backgrounding retains the command deadline, use `timeout: 0` only when
  intentionally unbounded, and record the returned job ID. A long-lived process is a named `bash`
  service: a project-unique `name`, the `command`, an optional `cwd`, and `ready`, with no `async`
  and no supplied `timeout`. When both `ready.log` and `ready.port` are given, both must pass. Read
  its status and logs with `read proc://<service-name>`, send stdin with `write
  proc://<service-name>` (empty input is allowed), change its mode with `write
  proc://<name>/mode` set to `persist`, `session`, or `detached`, and stop or cancel with `write
  proc://<id>/kill` and no content. A service exit notifies the session. A non-zero exit is a fail.

## architect, arena, interrogate, reflect

These workflows need independent contexts and benefit from different model priors. They route
through the shipped `pstack_panel_<n>` agents via `skill://pstack-omp`, which holds the panel rules.
A routed workflow requires its exact agent, so a blocked name is reported as an unavailable
configured route rather than replaced by a generic worker. Record resolved-model and fallback
evidence from the results. When fewer than two slots are configured the panel still runs two
independent contexts on the inherited model and says that model diversity is weaker. When
independent execution itself is unavailable, report the blocked gate.
- **arena** Phase C and **interrogate**: the judge's and reviewers' read-only grant is posture per
  **Every task call**, not a sandbox. Arena runs one cross-judge after candidates freeze.
- **reflect** step 3: keep Divergent on a different family from Judgment when configuration allows.
  Divergent runs on `pstack_panel_2` and Judgment on `pstack_judgment`. The lens earns its name from
  different priors, not a different prompt, so report it when the two resolved to the same model.
- **interrogate** step 2: a panel slot with no override inherits the parent model, which is the case
  where the family spread collapses first.
- A retry can move a spawn off the model its entry named, because retry fallback chains and
  extension routing hooks can change the final model. Record the model each arm actually ran on.
  `task.showResolvedModelBadge` prints it in the task widget.

## bug-fix

Amends step 2. Before reaching for runtime evidence, narrow the suspect set statically with `lsp`
action `definition` for where a value is set and `lsp` action `references` for every caller of a
suspect function. `task.enableLsp` is off by default, so a delegated worker has no `lsp` tool at
all and this narrowing is the parent's job unless that setting is on.

When program state is unclear the `debug` tool is the first instrument, ahead of bespoke logging.
With `debug.enabled` on, launch the reproducing path with action `launch`, drop a `set_breakpoint`
on the suspect line, drive it with `step_over` and `step_in`, and read exact state with `evaluate`.
Fall back to logging only when the tool is off or the runtime has no adapter.

## feature

Amends step 5. Run the typecheck and lint lane with `lsp` action `diagnostics` alongside the test
lane, and require the new code clean before the surface check. Workspace diagnostics (`file: "*"`)
run a checker for every detected supported language, at most two concurrently, and cap each
language's output at 50 lines. They report a total server failure explicitly, and a non-zero empty
checker result is reported as not verified. A partial failure still lets the other checkers report,
so a clean section covers only the languages that were actually checked. The supported project
types are limited to what the tool detects (Rust, TypeScript, Go, Python); a clean result is not
proof for any language it did not check. For a targeted server diagnostic, name concrete files, or
a glob capped at 20 files, and confirm a server is live with action `status`. With `lsp.enabled`
off, or for a language the tool does not check, fall back to the project's own typecheck and lint
commands.

## refactoring

Amends step 5. A text rename silently misses callsites, so the language server is the guard and not
an eyeball spot-check. With `lsp.enabled` on, take the migrate-every-caller inventory from `lsp`
action `references` and apply each rename with action `rename`, which builds and applies a real
`WorkspaceEdit`. For a module move use action `rename_file`, which rewrites every import across
files. Both actions apply by default, so pass `apply: false` to preview one. Run action
`diagnostics` over the touched files afterwards, naming them rather than `"*"`. Then grep string
literals, prose, and back-references by hand, which a symbol rename never touches. With the tool
off, or in a worker spawned while `task.enableLsp` is false, a project-wide grep of the symbol name
is the whole guard.

## swarm

Amends steps 3 through 6. Every worker already runs on this machine. Read **Every task call** for
the `isolated: true` gate, the per-worker output fallback, and the yield-first line, all of which
this skill depends on.

For a long open-ended item stream, eval's `workpool()` beats a fixed `tasks[]` array. It queues
items onto keep-alive workers, `eval.workpool.freshAgents` opts into a new agent per item, and the
pool name is its aggregate job id. Leave eval and let the result auto-deliver; use the `wait` tool
only when blocked. A fixed coverage matrix stays one `task` call.

## multi-phase-plan

The plan template's read list points at loaded skill locations as `skill://<name>/...`, not an
install path, because the skill is loaded from wherever the host put it. `scripts/check-plan.mjs`
requires three markers in a generated plan: the execution playbook URI
`skill://poteto-mode/playbooks/`, the words `audit tick`, and the words `status message`. Its live-lane
marker names an actual agent in backticks, never a guessed model selector. The plan must not invent
a product-repository file or an hourly `/loop` API to satisfy the checker. The verification-box
checks stay intact.

For the control-surface line, the omp doc for that surface is the artifact to read, such as
`omp://tools/browser.md`. Read **Control surfaces** below before writing the line, because the
artifact describes an eval prelude and not a tool.

## orchestrate

The root starts every participant through `skill://pstack-omp`. Track owners return briefs for
the root to dispatch; ordinary children never spawn children. Concurrency and isolation depend
on the live schema and runtime, not on a fixed nesting depth.

Coordinate with the live operations in `skill://pstack-omp`. The Agent Hub is a human-facing view and
not a tool. `write` to `agent://<returned-id>` sends a message and `agent://all` is for an
intentional broadcast. `read history://` lists registered agents and transcripts, `read proc://` lists
jobs, running agents without a job row, and services, and messages self-deliver with no inbox to
drain. The `wait` tool takes no arguments and is for when the root is blocked. These reach this omp
process's agent tree and nothing outside it. `collab.autoStart` and `omp collab link` host a session
for a human to watch or drive, which is not an agent-to-agent channel and gives a coordinator no way
to reach another session's workers. The root, not an owner, accepts and merges.

## Control surfaces

`browser` and `computer` are not tools and have no schema of their own. Since 18.1.9 both are
preludes inside the `eval` runtime, gated by `browser.enabled` and `computer.enabled`, so every
call is code in an `eval` cell, as in
`const tab = await browser.open({ name: "main", url }); await tab.close();`. Element handles come
from `tab.observe()` through `tab.id(n)` and from `tab.ariaSnapshot()` through `tab.ref("e5")`, and
a navigation invalidates both, so re-observe and act in the same cell. `computer` drives native
desktop the same way, through `computer.window(...)`, `win.ax()`, and element handles. Prefer the
accessibility tree over pixel coordinates, and never mix accessibility coordinates with screenshot
pixels.

omp freezes its own headless tabs when a turn settles (`browser.freezeOnTurnEnd`) and closes them
after `browser.idleCloseSec` idle seconds, so a login or any flow that must survive across turns
passes `persist: true` to `browser.open`. A prelude call emits no tool call and no tool result, so
a verification claim resting on one cites the cell's own output as its evidence.

## make-bot-ui

Creating, storing, and waking a Grok routine has no counterpart here, and serving an ordinary page
does. Read `references/make-bot-ui-on-omp.md` before starting, and never stand up a webhook
routine on omp.

## typescript-best-practices

omp carries `globs` as skill metadata and does not auto-attach a skill on a file match. Read
`skill://typescript-best-practices` yourself when you touch a `.ts` or `.tsx` file.

## setup-pstack

Setup writes `task.agentModelOverrides`, and nothing else, in the effective user configuration, not
a Cursor rule file. `references/setup-pstack-config.md` holds the routing contract, the six owned
keys, the value format, the file that is edited, and the panel rules. The skill's example block is
the role-to-capability table, not the file format.

`omp models --json` lists the machine's selectors with supported thinking levels, and step 1 must
group them by family and count the families, because the review roles are defined by family
difference. `omp config get task.agentModelOverrides --json` prints the persisted map, but overlays
and runtime overrides can outrank it. Setup neither changes the active chat model nor requires a
restart for later task launches.

## MCP discovery

Several skills and standalone workflows need to know which MCP servers exist. Do not assume one file.

1. Start from the live tool inventory: the MCP tools actually exposed in this session are the ground
   truth for what can be called now.
2. Run `/mcp list`, which shows each server and the config file it came from.
3. For servers that are not connected, read the effective configuration: project `.omp/mcp.json`,
   the active profile's user `mcp.json`, plugin and extension-package servers, and the imported
   Claude Code, Codex, Gemini CLI, OpenCode, Cursor, Windsurf, and VS Code sources. Honor
   `mcp.enableProjectConfig`, which can exclude every project-level source, and the user
   `disabledServers` and `enabledServers` lists. The default user file is one source among several.

See [MCP configuration](omp://mcp-config.md). Report the source path for any server a conclusion
rests on, and report a discovered-but-disabled server as disabled rather than absent.

## recall, reflect, eval, session-pickup, show-me-your-work, automate-me

All five read the session store. `references/session-store-on-omp.md` holds the layout. Four facts
decide whether a glob finds anything.

- The root is resolved, not fixed. Resolve the effective session directory first, honoring the CLI
  `--session-dir`, the profile, the environment, and XDG relocation, before globbing.
- The bucket is the canonicalized cwd with each `/` rewritten to `-`, which leaves a leading
  hyphen for a path under `$HOME`, so `~/Desktop/proj` is the directory `-Desktop-proj`. Stay
  inside your own bucket and the authorized workspace. Globbing sibling buckets reads private
  sessions from unrelated projects.
- A transcript's first line is a fixed-width `type:title` slot and not a message, and persisted
  roles are camelCase, so the spelling is `toolResult` rather than `tool_result`.
- For an agent in this process, skip the glob. Bare `history://` lists registered agents and
  transcripts, `history://<id>:1-50` pages one transcript, and `agent://<id>` serves that agent's
  final output. A nested child's ID is dotted, as in `agent://Parent.Child`.

## Upstream text that does not apply here

These stay as upstream wrote them, because the port has nothing to substitute.

- **poteto-mode** routers and **babysit** step 0 warn against Cursor's built-in `babysit` skill.
  omp ships no such skill, so the warning is inert and the playbook is the only route anyway.
- **bugbot-triage** rates Bugbot, which is Cursor's hosted review product. On a repository without
  it, apply the rubric to whatever review bot posts on your PRs, omp's own `security-reviewer`
  included.
- **make-bot-ui** names `api2.cursor.sh` and the routine panel. Both are Grok Bot surfaces.
- **worktree-cleanup** step 6 lists `~/Library/Application Support/Cursor` among macOS reclaimers.
  There is no omp equivalent worth pruning, and the rest of that step is Xcode and package caches.
- **orchestrate** names Graphite (`gt`) for stack operations. `command -v gt` finds nothing on this
  machine, so every `gt` step is unexecutable as written and `gh` covers single-PR flows.
