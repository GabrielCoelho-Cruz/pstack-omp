# The omp task wire

Amends **Every task call** in `SKILL.md`. Read this before a fan-out whose workers need their own
model, their own worktree, or a budget. Every fact below is one `omp config list`, `omp config get
<key> --json`, `omp://tools/task.md`, or `task` schema read away, so probe rather than trust this
file after an upgrade.

## The item shape

With `task.batch` on, which is the default, one call is `{ context, tasks: item[] }` and one item is
`{ name?, agent?, task, solutionSpace, effort?, outputSchema?, schemaMode?, isolated?, tools? }`.
`task` and `solutionSpace` are required. There is no `model`, no `readonly`, no `apply`, and no
`merge` on an item.

`solutionSpace` says how open the child's problem is: whether the fix or design is given, or which
causes or designs remain open. Examples are `one fix: rename, names given` and `deadlock cause open,
no repro`. Work volume never widens it. The host uses it to classify the child's thinking when that
child runs on an `auto` selector, and `effort` overrides it.

`context` is required and non-empty in batch shape, and it is rendered into every spawn's system
prompt. Put the shared contract there once instead of repeating it per item. Item names must be
unique within a call, compared case-insensitively.

With `task.batch` off the shape is flat, exactly one spawn per call, and `tasks` and `context` are
both rejected. Shared background then goes in a `local://` file that each spawn's `task` names.
Subagents share the parent's `local://` root, so that path resolves for them.

```json
{
  "context": "# Goal\nCollect retry settings.\n# Constraints\nRead-only; no children.\n# Contract\nFinish through yield.",
  "tasks": [
    {
      "name": "RetryScan",
      "agent": "pstack_fast",
      "task": "Read src/net and report every retry limit with file:line evidence.",
      "solutionSpace": "answer is in the code; locations unknown, no design choice"
    }
  ]
}
```

`effort` is `"lo" | "med" | "hi"`. It is present in the schema only while `task.enableEffort` is
true, which defaults to false, and it is clamped by `task.maxEffort`, which defaults to `max`. Check
`omp config list | grep task.enableEffort` before writing a brief that depends on it.

`tools` names kernel tools the parent defined in an `eval` cell with `@tool` in Python or
`tool(fn, …)` in JavaScript. It is gated by `eval.tools.enabled`, which defaults to true. Each call
runs inside the parent's kernel. An unknown name fails the call. It grants no harness tool.

## Background and inline

`async.enabled` decides whether an ordinary spawn runs as a background job. With it on, the call
returns job and agent IDs immediately and each result auto-delivers. With it off, the call blocks
until the spawns settle. Execution mode is per item: a custom agent that declares `blocking: true`
runs inline while non-blocking items in the same call still spawn as background jobs. No bundled
agent declares `blocking: true`, and the shipped pstack routing agents do not.

## The per-agent levers

Model routing is `task.agentModelOverrides`, keyed by the exact, case-sensitive agent name, and it
beats the agent file's frontmatter. pstack's six owned keys, the value format, and the panel rules
live in `setup-pstack-config.md`. The shipped agents declare no `model`.

Three more records sit beside it, keyed the same way, and pstack does not write them. They are the
operator's.

- `task.agentServiceTierOverrides` picks the provider service tier, one of `inherit`, `none`,
  `auto`, `default`, `flex`, `scale`, `priority`. It overrides `tier.subagent` and applies only
  where the resolved model's provider family supports the value.
- `task.agentPrewalk` arms prewalk, which starts the spawn on its resolved model and hands off to a
  cheaper one at the first edit or write. Values are `"on"`, `"off"`, or a model pattern.
  `task.prewalk` arms the same behaviour for the bundled `task` agent only.
- `task.agentAdvisor` pairs the spawn with an advisor model. Values are `"on"`, `"off"`, or a model
  pattern. Subagents run unadvised by default.

A slot with no entry in any of these runs on the parent's model with no tier override, no prewalk,
and no advisor. That is the correct default for most roles.

Retry fallback chains and extension routing hooks can change the model that finally answers, so a
panel that depends on family spread should record the resolved model each arm actually ran on. A
task result carries the resolved model and a fallback flag, and `task.showResolvedModelBadge`
displays the model in the task widget.

## Isolation

`isolated: true` appears in the schema only while `task.isolation.enabled` is true and plan mode is
disabled. Check both. The workspace is a clone of the current checkout produced by the backend
`isolation.backend` resolves, so the parent's uncommitted work is in the worker's starting state,
and the result is diffed against a baseline captured at spawn time.

- `task.isolation.apply`, default true, decides whether a successful run's changes land in the
  parent checkout. Turn it off to hold patch or branch artifacts for review first.
- `task.isolation.merge` is `patch` or `branch`. Branch mode commits to `omp/task/<id>` and
  cherry-picks. Patch mode writes `<id>.patch` and applies it only when it applies cleanly.
- `worktree.base` is the parent directory for isolation copies and `github` PR checkouts. Unset
  means `~/.omp/wt`. `OMP_WORKTREE_DIR` overrides it.

A kept-alive isolated agent retains its workspace through idle and parked transitions, and a direct
message revives it in-process. Releasing it captures the final changes and cleans the workspace. A
hard abort is terminal. After a host restart, isolated children cannot be cold-revived, so reconcile
the durable artifacts (patches, branches, transcripts) and dispatch replacement work. Do not confuse
that restart limit with normal in-process parking. A non-isolated run ends `idle` with its session
attached and is revivable.

## Budgets and lifecycle

- `task.maxConcurrency` caps concurrent subagents. The default is 32 and 0 is unbounded. Task's
  semaphore is resized in place from the live setting before each acquire and release, so a
  mid-session change affects work already queued. Each eval `workpool()` caps its own live workers
  at the same setting, separately. Eval's `agent()` takes no slot there and counts against the
  session-wide `async.maxJobs` cap shared by every background job in the session.
- `task.maxRecursionDepth`, default 2, caps nesting. At the cap the `task` tool is hidden from the
  child. An agent file needs `spawns` for its agent to nest at all. The pstack routing agents declare
  none, and their bodies forbid children.
- `task.softRequestBudget`, default 200 assistant requests, injects a wrap-up notice on crossing
  and force-stops the run at 1.5 times the budget so it yields partial findings. 0 disables it.
- `task.maxRuntimeMs` is a hard wall clock per spawn in milliseconds. 0 disables it. A timeout
  aborts the agent terminally.
- `task.agentIdleTtlMs`, default 420000, is how long an `idle` agent stays in memory before parking
  to disk. A `write` to `agent://<id>` revives a parked agent. `Main` is never parked.
- `task.enableLsp`, default false, decides whether a spawn gets the `lsp` tool at all.
- `task.eager` is `default`, `preferred`, or `always`, and sets how hard the harness pushes work
  toward subagents.

## Reading status

`read proc://` lists visible jobs, running agents without job rows, and project services, and one
`read proc://<returned-job-id>` reads a single status. Neither consumes the automatic delivery.
Cancel with `write proc://<id>/kill` and no content. The `wait` tool takes no arguments and is for
when the caller is blocked with nothing else to do.

## Plan mode

While a plan is being written, a spawn is restricted to `read`, `grep`, `glob`, and `web_search`,
its `spawns` and `prewalk` are cleared, and `isolated` and `tools` are rejected. A pstack fan-out
that needs workers to edit or to nest must run outside plan mode.
