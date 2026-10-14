# The omp shape of pstack's model configuration

Amends **setup-pstack**. The skill's role table says which capability each workflow role needs. This
file is the file format, the routing contract, and the panel rules.

## One mechanism

Model routing is one settings record, `task.agentModelOverrides`, mapping an exact agent name to one
concrete model selector. pstack ships six model-free agent definitions, and the routed workflows
select them through the `agent` field of a `task` item. Nothing else carries a model: no per-call
`model`, no extra pstack configuration file, no extension routing hook, and no `modelRoles` layer
that pstack depends on.

Resolution order for a spawn is the settings override, then the agent file's frontmatter (the
shipped files set none), then the parent/configured task fallback. So an agent with **no entry runs
on whatever the parent session would have used**. Omission is the inherit value. Retry fallbacks and
extension routing hooks can still change the model that finally answers, so report the resolved
model that task results return rather than promising diversity from configuration alone.

See [task](omp://tools/task.md), [agent discovery](omp://task-agent-discovery.md), and
[models](omp://models.md).

## The six owned keys

| Key | Capability | Used for |
|---|---|---|
| `pstack_fast` | fast code, mechanical work | explorers, investigators, reflect tooling lens, swarm workers, delegated feature, refactoring, bug-fix, perf-issue, and hillclimb implementers |
| `pstack_judgment` | judgment and prose | explainers, why synthesizer, reflect judgment lens and synthesizer, explicitly hardest delegated tasks, other delegated prose or review |
| `pstack_panel_1` to `pstack_panel_4` | diverse-model panel slots | arena runners and cross-judge, architect runners, interrogate reviewers, reflect divergent (slot 2), swarm model-race arms |

These six names are the **setup-owned key set**. Setup may add, replace, or remove only these keys.
It never deletes by prefix, so an unknown `pstack_*` key, every other override, and all other
configuration records stay exactly as found. Setup does not write service-tier, prewalk, advisor,
retry-chain, or model-role records, and it does not edit installed agent definitions or any user
agent root.

## Values

A value is **one selector, never a list**, built from `omp models --json`:

- Take `selector` from a row of that output. Never rewrite hyphenated model IDs or invent a slug the
  command did not print.
- Append `:<thinking>` only when the row's `thinking` array lists that level. The budget labels map
  `unlimited` to `max`, `large` to `xhigh`, `medium` to `high`, and `small` to `medium`. When the
  requested level is unsupported, use the highest level in the array at or below it. When none is at
  or below it, ask the operator to choose. A row whose `thinking` is `null` keeps its bare selector,
  and setup says that its thinking is not controllable.
- `auto` is valid only as a documented thinking suffix. Never write a literal `inherit-parent`, a
  bare `auto`, a list, or an `@alias` as a pstack-written value.
- A choice to inherit means **remove that agent's key**, so the agent follows the parent.
- Existing operator aliases and `modelRoles` entries stay untouched. Setup may resolve one for
  display, but the value it writes is a confirmed concrete selector.

The budget is reported in setup's summary. There is no second persistent budget setting, and no
prose `# budget` line is read to route a worker.

```yaml
task:
  agentModelOverrides:
    pstack_fast: "<provider/fast-model>:<thinking>"
    pstack_judgment: "<provider/strongest-judgment-model>:<thinking>"
    pstack_panel_1: "<provider/model-family-1>:<thinking>"
    pstack_panel_2: "<provider/model-family-2>:<thinking>"
    pstack_panel_3: "<provider/model-family-3>:<thinking>"
    pstack_panel_4: "<provider/model-family-4>:<thinking>"
```

The angle-bracket values above are placeholders. Only setup's own output, built from the machine's
`omp models --json`, contains real selectors. Write any subset: `pstack_panel_3` and
`pstack_panel_4` are optional, and an omitted key inherits.

## Which file is edited

Edit the effective **user** configuration under the active profile and agent directory, not a
remembered default path:

1. `omp config path` prints the agent directory in effect for this process, including profile,
   `PI_CODING_AGENT_DIR`, and XDG relocation. The user file is `config.yml` there.
2. Edit a project `.omp/config.yml` or an overlay file only when the operator names it.
3. Read the effective value from every layer that can supply it. `omp config get
   task.agentModelOverrides --json` shows the persisted settings, but `--config` and
   `PI_CONFIG_FILES` overlays and runtime overrides can outrank them. When a higher layer supplies a
   key, display that value instead of claiming the lower-layer edit won.

See [configuration](omp://config-usage.md) for the layer order. Change only the six keys, keep every
other entry and comment, and write the file so a re-run is idempotent. New values apply to task
launches from this point on. Setup changes neither the active chat model nor the session.

## Panel selection

A map value is one selector. Each configured numbered key is one reusable model slot, not a
participant list.

- For arena runners, architect runners, and interrogate reviewers, read
  `task.agentModelOverrides` from the **effective session settings** and take configured
  `pstack_panel_<n>` slots in numeric order. If fewer than two are configured, append the
  lowest-numbered missing slots until there are two. An unconfigured installation therefore still
  runs two independent contexts without promising different models.
- By default run one participant per selected slot. An explicit larger N repeats the selected slots
  round-robin with a unique task `name` for every run. N is not capped at four. Unconfigured slots do
  not encode extra persistent seats; an explicit N supplies extra runs.
- Arena runs exactly one cross-judge after candidates freeze. Prefer a configured slot whose model is
  known to differ from the writer's family, and otherwise use slot 1 and state the diversity limit.
  Decide the family from model metadata and returned resolved identities, never from provider alone
  or a slug prefix. When the writer's family is unknown, do not claim a comparison was proved.
- Reflect keeps its three lenses and a separate synthesizer: tooling on `pstack_fast`, judgment and
  synthesizer on `pstack_judgment`, divergent on `pstack_panel_2`. A divergent slot that should
  differ from judgment is reported when it does not.
- Swarm repeats `pstack_fast` for ordinary N-way work. A model comparison assigns the shipped panel
  slots to its arms. It never asks the operator to create agent files.

Report the resolved models that task results return, including the fallback flag. If a run shows
that two slots resolved to the same model, say so.

## Installation and discovery

The marketplace install ships the plugin's `agents/` directory, and omp-origin marketplace roots do
not need a foreign-source opt-in. After `/marketplace install`, run `/reload-plugins` so the new
agents appear, and restart omp when an extension module is new. Do not add native-root agent
symlinks, and do not enable unrelated plugins to make the names resolve.

A routed workflow needs its exact agent name. When discovery or policy blocks it, report the
unavailable configured route. Never fall back to a generic `task` call and claim setup took effect.

## Vibe

Vibe exposes only `fast` and `good`. The six names are not selectable there, so per-role task
routing from setup is unavailable on that surface. Do not rewrite the unrelated `sonic` or `task`
overrides to imitate it. A request that needs exact model-role execution reports the missing task
capability.

## Report

Setup's final report names which of the six keys it wrote, replaced, or removed, which file it edited,
any higher-priority layer that overrides a result, each written selector with its thinking suffix or
the fact that thinking is not controllable, and that new task launches use the values without a
restart.
