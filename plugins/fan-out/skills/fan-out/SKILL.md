---
name: fan-out
description: Run many subagents in parallel on one machine (swarm, coverage matrix, race, gauntlet, N-wide sweep, "run 100 agents"). Read before any wide run: it separates the three concurrency limits, shows an eval pattern that waits for handles before reading results, and covers isolation, aggregation, and per-slice failure handling.
---

# Fan-out

Run N subagents at once, drain them, return one report. omp already has the mechanical pieces, so nothing here needs new tooling. When the pstack plugin is also installed, its `pstack-omp` adapter skill owns dispatch mechanics and takes precedence over examples here.

## Pick the shape first

- **Partition.** N disjoint slices, each worker owns one. Every slice must come back or the sweep is incomplete.
- **Race.** N workers on the same brief. Declare the selection rule before spawning: `first pass`, `rank all`, or `best-of`.
- **Gauntlet.** N adversarial checks against one artifact. Retain majority survivors, not lone findings.

Mixing partition and race is fine. Say which is which in the briefs.

## Three different limits

Do not conflate these.

- **Task semaphore.** `task.maxConcurrency` (default 32, `0` unbounded) bounds one session-wide semaphore that every `task` spawn, inline or background, acquires. It is resized from the live setting before each acquire and release.
- **Per-pool width.** Each eval `workpool()` caps its own live workers at `task.maxConcurrency` separately.
- **Shared async-job cap.** Eval's `agent()` takes no `task.maxConcurrency` slot. Each handle is a background job that counts against the session-wide `async.maxJobs` cap (default and maximum 100). Async `bash`, async `task` spawns, pools, and nested agents' jobs share it, and `agent()` fails with `Background job limit reached` when it is full.

```bash
omp config get task.maxConcurrency --json
omp config set task.maxConcurrency 100
```

Check the effective value and observe the width a run actually reaches. Do not assume a changed setting took effect for a wave that already started. Keep trees flat: nested spawns hold slots under the same limits, and `task.maxRecursionDepth` (default 2) bounds nesting.

## Two ways to dispatch

**`task` tool.** Use when each worker is a self-contained assignment. With `task.batch` on, send one `{ context, tasks: [...] }` call, and each item needs `task` and a `solutionSpace` that says how open its problem is, not how much work it is. With it off, start one flat call per spawn before waiting. `async.enabled` controls whether results are delivered in the background or the call blocks. Set `isolated: true` per item when workers write files, if the schema exposes it: each gets its own workspace and its changes are captured by patch or branch.

**`eval` with `agent()` and `wait()`.** Use when the fan-out is computed or feeds results into more code. `agent()` returns a handle immediately, not a result. Collect handles, wait for them, then read the values:

```js
const briefs = [
  "Read-only: list the top-level directories in this repo and say what each holds.",
  "Read-only: find the largest file under this repo's top level and report its size.",
];
const hs = await Promise.all(briefs.map((b) => agent(b, { agent: "scout" })));
const results = await wait(hs, { raiseErrors: false });
display(results);
```

`wait(hs, ...)` returns values in input order. With `raiseErrors: false` a failed or cancelled handle is returned in its own slot as the error object, so inspect every slot and account for each partition or racer. Never index into a handle as if it were its result.

In Python the same pattern uses the synchronous helpers. `agent()` returns an awaitable handle, and awaiting it consumes its result, so do not await it inside the comprehension. `wait()` is synchronous and returns a list, so do not await it either:

```python
hs = [agent(b, agent="scout") for b in briefs]
results = wait(hs, raise_errors=False)
display(results)
```

For an open stream of items, use `workpool()`:

```js
const pool = await workpool({ agent: "scout", name: "sweep-1" });
await pool.push(...items);
```

The pool name is its aggregate async job id. Its first full drain settles and closes the pool, and the aggregate result auto-delivers once. Leave the cell and use the zero-argument `wait` tool only when blocked. There is no `pool.wait()`, so the kernel stays free. Create a new named pool for another phase. `pool.status()` and `pool.peek()` read state without consuming it.

## Failure handling

Decide per slice or per racer, not with a blanket rule.

- **Partition.** A missing or failed slice is incomplete work. Re-dispatch exactly that slice, or report it as not covered.
- **Race.** Apply the declared rule to the results that came back, and state how many arms completed.
- **Gauntlet.** Count only completed checks toward a majority, and say how many checks were lost.
Schema-bound subagents can return the wrong shape. When a result fails its contract, re-dispatch that item or relax the output contract rather than guessing at the intended fields. Put schema-bound or judgment work on a stronger model through `task.agentModelOverrides` and a named agent.

## Historical observation

One run on one configuration, kept for context only and not a failure rate, a speedup promise, or a width recommendation. On one machine a 100-item `parallel`-style batch of `sonic` agents with a structured-output schema completed 92 of 100 in 343 s of wall time. A same-task rerun at width 20 completed 16 of 20, at width 8 `sonic` and `task` completed 6 of 8 each, and `scout` completed 8 of 8. The cause was not isolated. The failed items returned an improvised envelope rather than the requested schema. Probe your own configuration before relying on any number.

## Aggregate

Read the terminal results yourself and write your own summary. Never paste raw worker dumps. For a partition, confirm every slice returned. For a race, apply the rule you declared up front. For a gauntlet, keep findings that survived a majority of skeptics, and verify each survivor against the source before acting on it.

Workers do the legwork. The correctness of the conclusion is yours.
