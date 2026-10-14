---
name: how
description: "Use for \"how does X work\", code walkthroughs before changing something, and placement / ownership / layering questions (\"where should this live\", \"which package owns this\", \"is this the right layer\"). Explains subsystem architecture, runtime flow, onboarding mental models. Use why for motivation."
---

# How

Explore the codebase to answer "how does X work?" questions. Produce architectural explanations at the level of a senior engineer onboarding onto a subsystem, enough to build a working mental model, not so much that it reads like annotated source code.

Dispatch through `skill://pstack-omp`. Setup's model choices reach each spawn through the exact agent named in its task item's `agent` field, as described in `skill://omp-mechanics/references/setup-pstack-config.md`. Every explorer runs on `pstack_fast` and every explainer runs on `pstack_judgment`. Both are read-only by posture stated in the brief, which is not a sandbox. Each brief tells the worker to start no subagents and to finish through `yield` with its findings and evidence. Every task item carries a `solutionSpace`. If discovery blocks an agent name, report the unavailable configured route. Never fall back to the generic worker and claim setup took effect. Leave each subagent's thinking to its route, per the Subagents section of the **poteto-mode** skill.

## 1. Assess complexity

If the scope is ambiguous, state your interpretation and explore. The user can redirect.

- **Simple** (a single module, a small utility, a narrow question such as "how does function X work"): no explorers. Spawn one explainer on `pstack_judgment` that explores and explains in one pass, built from `references/explainer-prompt.md` without the explorer-findings section. Go to step 4.
- **Complex** (a subsystem spanning multiple files or services, a cross-cutting feature, a full architectural overview): go to step 2.

When in doubt, take the simple path.

## 2. Explore (complex only)

Decompose the question into 2 to 4 angles, each a distinct slice of the subsystem. Spawn all explorers together through `skill://pstack-omp`, in the batch or flat shape the live `task` schema accepts, each on `pstack_fast` with `references/explorer-prompt.md` and its angle filled in.

## 3. Synthesize (complex only)

Once all explorers have returned, spawn one explainer on `pstack_judgment` with `references/explainer-prompt.md` and every explorer's findings filled in.

## 4. Present

Present the explainer's output. Light edits for clarity or context from the conversation are fine. Do not substantially rewrite it.

## Output format

The explanation uses the sections defined in `references/explainer-prompt.md`, dropping any that do not apply: Overview, Key Concepts, How It Works, Where Things Live, Gotchas.
