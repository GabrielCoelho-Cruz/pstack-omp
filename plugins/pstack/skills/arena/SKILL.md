---
name: arena
description: "Spawn N parallel candidates at the same task, pick a base, graft the strongest parts of the losers into it. Use for /skill:arena, 'arena this', 'throw it in the arena', or when one attempt at a non-trivial artifact would lock in the wrong shape."
---

# Arena

Open a todolist with one entry per phase (Frame, Fan out, Cross-judge, Pick, Graft, Verify) before launching anything.

## Phase A: Frame

Every candidate gets the same prompt, so the prompt is the contract.

1. State the artifact each candidate is producing.
2. Derive the rubric, 3-6 concrete gradeable criteria for what success looks like on *this* task. It is the picker's tool in Phase D. Candidates only see the task.
3. Pick the runners. Runners are the numbered panel agents `pstack_panel_<n>`, routed through `skill://pstack-omp` and configured as described in `skill://omp-mechanics/references/setup-pstack-config.md`. Read `task.agentModelOverrides` from the effective session settings and take the configured `pstack_panel_<n>` slots in numeric order. If fewer than two are configured, append the lowest-numbered missing slots until there are two. Use one runner per selected slot. When the arena covers multiple design directions, or the work is generation-bound rather than judgment-sensitive, an explicit larger N repeats the selected slots round-robin. N is not capped at four. If discovery blocks a required agent name, report the unavailable configured route. Never fall back to the generic worker and claim the setup took effect. Vibe has no routing agents, so per-role routing is unavailable there. Pick each subagent's reasoning `effort` for the job when the live `task` schema exposes it, per the Subagents section of the **poteto-mode** skill.
4. Give each candidate its own output location (a git worktree where possible, otherwise `/tmp/arena-<slug>/candidate-<n>/`), per the **separate-before-serializing-shared-state** principle skill.

## Phase B: Fan out

Spawn all N subagents together through `skill://pstack-omp`, in the batch or flat shape the live `task` schema accepts. Each task item sets `agent` to its `pstack_panel_<n>` slot, a unique `name` per run (required, since slots repeat when N exceeds the slot count), and a `solutionSpace`. Each gets the task, the path to the shared grounding, its own output path, and instructions to produce the artifact and a short rationale naming the alternatives it considered and what it rejected. Report each returned resolved model and fallback flag. Claim model diversity only when those returned identities prove it.

If a candidate produces no output, proceed with N-1 and note the dropout.

## Phase C: Cross-judge

After all Phase B candidates complete, spawn exactly one cross-judge from the `pstack_panel_<n>` slots. Prefer a configured slot whose model is a different model family from the writer's, judged from model metadata and the returned resolved identities, never from provider alone or a slug prefix. Otherwise use slot 1 and state the diversity limit. If the writer's family is unknown, do not claim a cross-family comparison was proved. Give the judge a brief that grants read-only posture. It sees the rubric and the candidates by path label, scores each criterion, and recommends a base with rationale. It runs in parallel with your reading in Phase D. Don't spawn it while candidates are still writing. Report its resolved model and fallback flag.

## Phase D: Pick a base

Read every candidate end to end before picking. Score each against the rubric criterion by criterion, not on holistic feel, and compare with the cross-judge. Agreement on the base confirms the pick. Disagreement means one of you is biased or the rubric was ambiguous. Read both rationales before deciding.

Pick the base a future maintainer can extend most easily without breaking invariants. When two feel tied, prefer the cleaner boundary or smaller API, per the Laziness Protocol.

## Phase E: Graft

Walk each losing candidate once more for what is worth porting into the base, usually one or two things per candidate, not most of it. Fold each graft in by hand, per the **redesign-from-first-principles** principle skill, so the result stays coherent under one mental model. Don't paste mechanically.

If the candidates converge on one shape, that is strong agreement. Note it and ship the consensus shape. No graft is needed. If they wildly diverge, Phase A was under-specified. Reframe and re-run rather than averaging the divergence.

## Phase F: Verify

Verify the synthesized artifact like any other output, per the **prove-it-works** principle skill. If verification finds a problem the arena missed, either Phase A was wrong (re-frame and re-run) or a candidate caught it and you missed the graft (go back to Phase E). Don't paper over it.

## Outputs

One synthesized artifact, with a short synthesis note alongside naming the base and why, the cross-judge's verdict, each graft with its source candidate, what was rejected and why, any convergence or dropouts, and the verification result.
