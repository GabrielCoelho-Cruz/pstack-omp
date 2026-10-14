---
name: setup-pstack
description: Configure which models pstack uses per routing agent and at what reasoning budget. Detects your available models and thinking levels with `omp models --json`, then writes the six owned `task.agentModelOverrides` keys into your user settings. Use for /skill:setup-pstack, "configure pstack models", "pstack budget", or changing pstack's model choices.
---

# Setup pstack

Write `task.agentModelOverrides` in the effective user settings, the keyed override map that sets pstack's model per routing agent. The chat model stays the operator's choice, made with `/model`, and setup never changes it. `skill://omp-mechanics/references/setup-pstack-config.md` holds the routing contract and the file shape.

## Steps

### 1. Detect available models

Run `omp models --json`. Each row has a `selector` and a `thinking` field. `thinking` lists the supported thinking levels and may be null. That output is the dependable source. If you cannot detect any model, ask the user to paste the selectors they have access to. Never invent or rewrite a selector, and never write one you have not confirmed in this output.

### 2. Load current state

Read the effective settings, not a remembered path. Run `omp config path` for the agent directory and `omp config get task.agentModelOverrides --json` for the persisted map. Account for explicit overlays and higher-priority layers: if a higher-priority layer sets one of the six keys, show that value to the user instead of claiming your edit in the lower layer will win.

Setup owns exactly six keys: `pstack_fast`, `pstack_judgment`, and `pstack_panel_1` to `pstack_panel_4`. Preserve every other key, including unknown `pstack_*` keys, and every other record. Never delete by prefix. Treat the current values of the six keys as the current choices. With none set, start from an empty table.

### 3. Budget, map, and confirm

**(a) Ask for a budget.** Use the `ask` tool. Offer these four options with these exact labels, and name the current budget when the current selectors show one.

- `unlimited — max reasoning`
- `large — xhigh reasoning`
- `medium — high reasoning`
- `small — medium reasoning`

**(b) Apply it.** `unlimited`, `large`, `medium`, and `small` set the target thinking level to `max`, `xhigh`, `high`, or `medium`. For each concrete selector, append a `:thinking` suffix with the highest level that the model's `thinking` list supports at or below the target. If none is supported, ask the user to choose. A model whose `thinking` is null keeps the bare selector, and you tell the user so. `auto` is only a documented thinking suffix, never a model value.

**(c) Show the roles and confirm.** Show which workflow roles each key serves:

- `pstack_fast`: how explorers, why investigators, reflect tooling lens, swarm workers, and delegated feature, refactoring, bug-fix, perf-issue, and hillclimb implementers.
- `pstack_judgment`: how explainer, why synthesizer, reflect judgment lens, reflect synthesizer, an explicitly hardest delegated task, and any other delegated judgment, prose, or review.
- `pstack_panel_1` to `pstack_panel_4`: arena runners and cross-judge, architect runners, interrogate reviewers, swarm model-race arms, and the reflect divergent lens (always slot 2). Prefer one model per distinct family.

Show each key with its selector and suffix. Ask whether to accept as-is or change specific keys, offering the detected selectors. A choice to inherit the operator's model means remove that key.

### 4. Validate

Every concrete selector must appear in the `omp models --json` output, and its thinking suffix must be a level that row supports. If a chosen selector or level is not available, stop and ask again.

### 5. Write the owned keys

Write only the six owned keys into the effective user configuration, one concrete selector each, and preserve everything else. Do not write `modelRoles`, retry, service-tier, advisor, or prewalk records. Shape:

```yaml
task:
  agentModelOverrides:
    pstack_fast: "<provider/model>:<thinking>"
    pstack_judgment: "<provider/model>:<thinking>"
    pstack_panel_1: "<provider/model>:<thinking>"
    pstack_panel_2: "<provider/model>:<thinking>"
```

`skill://omp-mechanics/references/setup-pstack-config.md` holds the owned keys and the full file shape. Re-runs are idempotent: the same answers produce the same file, and a removed key stays removed.

### 6. Report

Tell the user which keys were written, replaced, or removed, which file was edited, any higher-priority overrides that still win, and each selector with its thinking suffix. State that setup neither changes the active chat model nor needs a restart for later task launches. New agents from a first marketplace install need `/reload-plugins`.

Panel rules, in one paragraph: routed workflows use the configured panel slots in numeric order, with at least two contexts; an explicit larger N round-robins the slots with unique task names; arena prefers a cross-judge slot known to differ from the writer's family; reflect divergent uses slot 2. Vibe has no per-role task routing. `skill://pstack-omp` holds the adapter.

### 7. Offer a verification skill (optional)

Check whether the project has a way to drive the real app for proof (a `verify-*` skill, or an existing harness). If not, offer once: "want a project-local verification skill, so agents can drive the app the way a user does and prove changes work? I can generate one with /skill:create-verification-skill." On yes, invoke `/skill:create-verification-skill` (resolves wherever pstack is installed: workspace, user, or plugin). On no, move on without pushing.
