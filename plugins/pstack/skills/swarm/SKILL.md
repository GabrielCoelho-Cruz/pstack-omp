---
name: swarm
description: "Fan out N parallel workers, drain them, and return one report. Use for /skill:swarm, 'swarm this', or parallel coverage, races, gauntlets, and exploration."
---

# Swarm

Fan out N parallel workers. They may cover separate slices, race the same brief, or mix both. The parent waits, aggregates, and returns one report.

## Start

Open a todolist with one entry per phase before launching anything.

1. Frame
2. Fan out
3. Aggregate
4. Report

## Phase A: Frame

1. State the done predicate and the artifact or report the swarm must return.
2. Choose the shape. Partition into slices, race N workers on identical briefs, or mix both. For a race or mixed shape, declare `first pass`, `rank all`, or `best-of` before spawning.
3. Set N from the user or derive it from the shape. N is total workers. The live `task.maxConcurrency` setting caps how many run at once, and the rest queue.
4. Pick the worker route through `skill://pstack-omp`. Setup's model choices reach each worker through its exact agent, as described in `skill://omp-mechanics/references/setup-pstack-config.md`. Default workers run on `pstack_fast`. For a model race, assign the shipped `pstack_panel_<n>` slots to the arms. Take the configured slots in numeric order from `task.agentModelOverrides` in the effective session settings, append the lowest-numbered missing slots until there are two, and run one arm per slot. An explicit larger N repeats the slots round-robin with a unique task `name` each. Never tell the operator to create agent files. If discovery blocks an agent name, report the unavailable configured route. Never fall back to the generic worker and claim setup took effect. Leave each subagent's thinking to its route, per the Subagents section of the **poteto-mode** skill.
5. Give each worker its own writable output when it writes. When workers verify or measure commits, each brief names the exact SHAs. A measurement brief also names the method (sample count, what one sample is, order). The worker records both in its result.

## Phase B: Fan out

Spawn all N workers together through `skill://pstack-omp`, each on the step 4 route, in the batch or flat shape the live `task` schema accepts. Every task item carries a `solutionSpace`. Add `isolated: true` only when the schema exposes it and the isolation gate in `skill://omp-mechanics` passes. A worker that needs this machine's installed tools, simulators, or local credentials runs in the shared checkout instead. For a model race, report each arm's returned resolved model and fallback flag, and claim a model comparison only when those prove the arms differed.

When a worker must start from a non-default base, create its `git worktree` on that base first and point the worker at that path.

Every brief stands alone. Include the goal, scope, exact slice or race arm, how to verify, and what to report. Tell the worker to start no subagents and to finish through `yield`. Reports use `PASS`, `ISSUES`, or `BLOCKED` with evidence. A worker that can prove a defect reports `ISSUES` and lists every issue it can prove, not only the first.

If a worker drops out, proceed with N-1 and note it.

## Phase C: Aggregate

Read the terminal results. Drop a result that does not record the SHAs and method its brief names, and respawn that worker once. After a second miss, record a gap. A gap does not count as a pass. For coverage, every required slice needs a result. For a race, apply the selection rule declared up front. Use first pass, rank all, or best-of. Do not paste raw worker dumps.

Keep a compact result table, one-line evidenced issues, and explicit gaps or dropouts.

## Phase D: Report

Return one consolidated in-chat report with the table, issue one-liners, gaps or dropouts, and the race rule when used.
