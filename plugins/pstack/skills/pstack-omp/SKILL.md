---
name: pstack-omp
description: "Translate poteto-mode roles and lifecycle protocols to the live OMP task or vibe worker surface. Use for pstack delegation, standalone briefs, panels, owners, and watchers."
---

# pstack on OMP

`skill://poteto-mode` selects the playbook, role, step order, and gates. This adapter owns dispatch mechanics. Read it before following a task-shaped instruction in any imported skill. Its live-tool mapping takes precedence over examples in imported prose. It does not weaken a playbook's verification or safety gate.

## Detect the live surface

Inspect the tools and schemas exposed in this session, not a version number or a remembered roster.

- With `task`, use the task contract below. Only pass fields actually exposed. Use `read`, `write`, `wait`, and `bash` for agent and job coordination exactly as their live schemas describe; see **Agents, jobs, and services** below.
- Without `task`, when `vibe_spawn`, `vibe_send`, `vibe_wait`, `vibe_list`, and `vibe_kill` are exposed, use the vibe contract below. Do not try to enable task or escape director restrictions.
- With neither surface, do bounded work directly only when the current mode permits it. If independent review or unavailable execution is required, report the exact missing capability. Never claim a panel ran locally as one session.

## Canonical roles

| Role | Task preference, if listed | Vibe tier | Brief posture |
|---|---|---|---|
| explorer | scout | fast | Read-only repository reconnaissance and artifact reduction. |
| watcher | scout | fast | Observe one generation and event, then finish. |
| planner | designer | good | Technical architecture and competing shapes. |
| designer | designer | good | Visual, interaction, and product design. |
| reviewer | reviewer | good | Independent code or behavioral verdict. |
| security reviewer | security-reviewer | good | Read-only security lane, separate from ordinary review. |
| researcher | librarian | fast | Source-verified external research. |
| synthesizer | reviewer | good | Adjudicate frozen evidence, not new implementation. |
| implementer | default worker | good | Bounded implementation with explicit write ownership. |
| owner | default worker | good | Retain context for one coupled workstream. |
| mechanical | sonic | fast | Fully specified low-judgment edits. |

The live roster is authoritative. Never invent missing specialists. This table is the **generic canonical-role fallback**: when a preferred specialist is absent, use an available worker with the role explicitly in its brief and omit `agent` for the default worker. `poteto-agent` and `comment-sicko` are optional bundled custom agents. Use their exact names only when discovered. Otherwise include their skill/agent instructions as file pointers in an available worker's brief.

## Configured model routes

Setup configures model choice with `task.agentModelOverrides[exactAgentName] = concreteSelector`, and pstack ships six model-free agents to carry it. Select a route with the item's `agent` field. Never send a worker model in a task or eval payload. The full contract, key list, and panel rules are in `skill://omp-mechanics/references/setup-pstack-config.md`.

| Assignment | `agent` |
|---|---|
| Delegated feature, refactoring, bug-fix, perf-issue, or hillclimb implementer; explorer, investigator, reflect tooling, swarm worker | `pstack_fast` |
| Other delegated judgment or prose; how explainer, why synthesizer, reflect judgment and synthesizer | `pstack_judgment` |
| An explicitly hardest delegated assignment | `pstack_judgment`, and say in the brief that it is the hardest task |
| Arena runners and cross-judge, architect runners, interrogate reviewers, swarm model-race arms | `pstack_panel_<n>` per the panel rules |
| Reflect divergent lens | `pstack_panel_2` |

A routed workflow requires its exact shipped agent. If discovery or policy blocks that name, report the unavailable configured route. Never silently dispatch the generic worker and claim setup took effect. Root work keeps the operator's model. A security-specific lane keeps its discovered restricted specialist and must not claim it used a pstack override.

Panel width: take configured `pstack_panel_<n>` slots in numeric order, and append the lowest-numbered missing slots until there are two. Run one participant per selected slot. An explicit larger N repeats those slots round-robin with unique `name` values. N is not capped at four. Arena runs exactly one cross-judge after candidates freeze, preferring a configured slot known to differ from the writer's family and otherwise slot 1 with the limit stated. Read the settings through the effective session settings, not a remembered file.

Agent selection is not a proof of model selection. A slot with no override inherits the parent model, and extension routing or retry fallback can still change the final model. Claim independence of models or providers only when returned resolved-model and fallback metadata proves it. Independent contexts remain useful when only one model is available; report that limitation.

## Standalone brief

Children start blank and do not inherit the parent conversation. Every brief must contain:

- **Target:** outcome, canonical role, repository/worktree, exact writable paths, forbidden paths, and output artifact.
- **Change:** relevant source pointers, settled contract, constraints, dependencies, base SHA or generation, and decisions already made.
- **Acceptance:** observable done predicates, required evidence, allowed verification commands or an explicit root-only validation rule, report format, and stop conditions.

Common immutable material belongs in batch context or an accessible artifact. Never substitute a file pointer for the brief's goal or ownership. Tell ordinary children not to start subagents or ask the user directly. A role change requires a fresh context. A coupled correction may reuse the owner. Children report only checks actually executed; the root independently accepts or rejects the result.

Every task item also carries a required `solutionSpace`: one short phrase on how open the child's problem is, such as `one fix: rename, names given` or `deadlock cause open, no repro`. It describes whether the fix or design is given and which causes or designs remain open. Work volume never widens it, and it is separate from `effort`.

## Task contract

Task shape follows the live schema. `task.batch` controls it: with batch on, one call is `{ context, tasks: [...] }` where `context` is required shared background and each item is `{ name?, agent?, task, solutionSpace, ... }`. With batch off the call is one flat item per spawn, and `tasks` and `context` are rejected, so put shared background in a `local://` file that each `task` names. Start all independent participants before waiting. Give each participant a unique `name` when named (compared case-insensitively) and a self-contained `task`. Shape `context` as Goal, Constraints, Contract. Omit `agent` for the default worker; do not write `agent: "task"` to request it.

```json
{
  "context": "# Goal\nMap how retries are configured.\n# Constraints\nRead-only. No children.\n# Contract\nFinish through yield with findings and file paths.",
  "tasks": [
    {
      "name": "RetryMapper",
      "agent": "pstack_fast",
      "task": "Target: read-only exploration of src/net. Report where retry limits are set, with file:line evidence. Acceptance: every claim cites a line you read.",
      "solutionSpace": "answer exists in code; locations unknown, no design choice"
    }
  ]
}
```

`async.enabled` controls ordinary background execution: with it on, spawns return job and agent IDs and results auto-deliver; with it off the call blocks until they settle. A custom agent that declares `blocking: true` runs inline even when `async.enabled` is on, and a mixed call runs both modes.

`effort`, `isolated`, `outputSchema`, `schemaMode`, and `tools` are optional only if exposed. Leave `effort` unset: the route's configured thinking decides, and `effort` would override it up to the model's top level. Set it only on the user's request or once after the route's level failed, and report the resolved level. `isolated` needs `task.isolation.enabled` and no plan mode. `tools` names eval-defined kernel tools, not ordinary tool grants. A task item has no assumed per-call `model`, `readonly`, `apply`, or `merge`. A read-only brief is not a sandbox. Use a restricted discovered specialist when available and still state the write ban.

Give concurrent writers disjoint paths or separate worktrees. If `isolated` is exposed, inspect returned isolation metadata to learn where changes landed. Otherwise arrange explicit worktrees through available execution, or serialize a genuinely shared write. Never switch branches in a shared checkout and call that isolation. Local isolation keeps its workspace through idle and parked states and can be revived in-process by a direct message; releasing it captures the final changes and cleans the workspace, and a hard abort is terminal. After a host restart, isolated children cannot be cold-revived: reconcile durable artifacts and dispatch replacement work.

Record returned agent and job identifiers. Results auto-deliver. Read complete output at `agent://<id>` (a child's own children are `agent://Parent.Child`; structured data is `agent://Parent.Child/reports/0/data`), and inspect `history://<id>` for incomplete or suspicious reports. Reuse a session only when the host reports it can be resumed. Cancel superseded jobs by exact ID with `write` to `proc://<id>/kill` and no content. Do not infer liveness from transcript timestamps; rely on returned status and durable branch or PR reconciliation.

## Agents, jobs, and services

The human-facing Agent Hub is not a tool. Use these exact operations, and only when the live schema exposes them:

| Need | Operation |
|---|---|
| List agents or transcripts | `read history://`. `read proc://` lists visible jobs, running agents without job rows, and project services. There is no inbox-drain tool and no documented bare `agent://` roster. Messages self-deliver. |
| Send to an agent | `write` to `agent://<returned-id>` with the message as content. Use `agent://all` only for an intentional broadcast. |
| Check job status | `read proc://` or one non-consuming `read proc://<returned-job-id>`. Never loop-poll while useful work remains. |
| Supervised process or service | `bash` with a project-unique `name`, `command`, optional `cwd`, and `ready` (log regex and/or port; when both are given both must pass). Do not combine `name` with `async` or any supplied `timeout`. |
| Service logs and status | `read proc://<service-name>`. |
| Stdin, stop, or mode | `write` to `proc://<service-name>` for stdin (empty input is allowed); `write` to `proc://<id>/kill` with no content to stop or cancel; `write` to `proc://<name>/mode` with `persist`, `session`, or `detached`. |
| Finite verification | Ordinary `bash`. Use `async: true` only when exposed; backgrounding keeps the command deadline, so use `timeout: 0` only when intentionally unbounded. Record the returned job ID. |
| Wait | The `wait` tool takes no arguments and returns on the first owned result, message, or interrupt. Use it only when blocked, and account separately for every required result. |
| Eval barrier | Eval's `wait(handles)` returns results in input order and is distinct from the `wait` tool. Eval workpools have no `pool.wait()`: leave eval, let results auto-deliver, and call the `wait` tool only when blocked. |

Reads of `proc://` do not consume automatic delivery. A service exit notifies the session. A named service observes work only while its session exists; it is not an out-of-session scheduler. For unattended scheduling use launchd on macOS or an available systemd user timer or cron on Linux, connected to an explicit CLI or authenticated RPC entry point, and never substitute one OS's scheduler for another. Authenticated RPC `prompt`, `steer`, `follow_up`, or an extension can inject outside work. Inspect live loop help before prescribing loop grammar or cadence.

## Vibe contract

These are documented OMP wire shapes; confirm the live schema before calling them:

- `vibe_spawn({ cli: "fast" | "good", prompt, name? })` starts a blank persistent worker. Put the canonical role and exact workspace in `prompt`; there is no task-style `agent`, `tasks[]`, `context`, or `isolated` field.
- `vibe_send({ session, message })` steers or resumes the recorded worker for a coupled phase or bounded correction.
- `vibe_wait({ sessions?, timeout? })` waits for a watched turn to settle. It is not an all-workers barrier. Account for every required participant before advancing.
- `vibe_list({})` gives current workers and resolved metadata.
- `vibe_kill({ session })` ends a superseded worker after required artifacts are durable.

Spawn independent workstreams before waiting. Use one persistent worker per coupled workstream. Workers share the configured workspace unless an explicit worktree is arranged in their briefs; do not assume isolation. Start independent verification in a separate worker after implementation artifacts freeze. A director without execution tools sends exact verification commands to that verifier, reads its evidence and touched files, and owns acceptance. It must not bypass its restricted tools to run commands itself.

Vibe exposes only `fast` and `good`, not the six `pstack_*` routing agents. Setup's per-role task routing is therefore unavailable there. Do not rewrite the unrelated `sonic` or `task` overrides to imitate it. If a request needs exact model-role execution, report that task capability as missing.

Results self-deliver into the director conversation; the vibe tool schema does not guarantee an `agent://<id>` resource, so use one when the runtime returns it and otherwise read the delivered report. Transcripts, when the runtime reports them, live at `history://<id>`. Preserve the actual returned identifiers instead of constructing them from display names. Vibe sessions belong to the current owner/scope; never control another scope's worker. Restarted workers require live-state reconciliation before sending new work.

## Lifecycle protocols

### Bounded session

Start one standalone assignment, collect its complete report and artifacts, then independently verify acceptance. An in-scope correction can go to the same resumable worker. A different role or unit gets a fresh worker.

### Panel

Partition slices or candidates with distinct ownership. Start all participants before waiting, track them by identity rather than arrival order, and account for missing or canceled lanes. Freeze candidates before separate reviewers start. Freeze reviews before a separate synthesizer. The root chooses; consensus is evidence, not proof.

### Long-lived owner

Keep one worker on one coupled unit. Record its workspace and identity. Send only coupled next phases, evidence-based answers, or bounded corrections. Require a report at each acceptance boundary; independently verify before authorizing the next phase. Do not give the same branch to a sibling owner.

### One-shot watcher

Observe one branch/head/generation and one exact predicate, with stop conditions and a time limit. Return one meaningful event and finish. A changed head invalidates the report and requires a new watcher. Watchers do not fix, merge, authorize, or follow a new generation silently.

## Root ownership

The root keeps user interaction, scope, approvals, integration, external-write authorization, merges, deletion decisions, and final verification acceptance. Ordinary workers skip shared formatting, linting, and project-wide suites unless their brief explicitly assigns that verification lane. Do not race validation against unfinished sibling edits.

A new commit, rebase, conflict resolution, or applied patch requires rechecking the evidence generation. Preserve patch-id exceptions only when the Shipping playbook explicitly permits them. Report PASS, ISSUES, or BLOCKED with exact paths, generation, executed commands, results, deviations, and remaining gaps. A successful worker exit is not artifact acceptance.
