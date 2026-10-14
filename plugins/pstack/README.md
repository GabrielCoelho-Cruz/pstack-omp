# pstack for oh-my-pi

The pstack methodology, ported to omp. It ships 55 skills, 23 playbooks, 24 principle leaves, the
`poteto-mode` pin, and 8 installed agents: six model-routing agents plus `poteto-agent` and
`comment-sicko`. 53 skills are built from upstream; `omp-mechanics` and `pstack-omp` are port
adapters. Licenses and third-party notices ship in `LICENSE` and `THIRD_PARTY_NOTICES.md` in this
directory.

## Install

From a clone, or from a published marketplace URL:

```
/marketplace add <checkout-or-marketplace-url>
/marketplace install pstack@pstack-omp
/reload-plugins
```

The marketplace install caches the plugin and ships its `agents/` directory, so the routing agents,
`poteto-agent`, and `comment-sicko` are discovered with no extra step. Omp-origin marketplace roots
do not need a foreign-source opt-in, and nothing here needs a native-root agent symlink. Run
`/reload-plugins` to pick up skills and agents after an interactive install. Restart omp once, so the
new `potetomode` extension module loads.

For local development, link the checkout instead:

```
omp plugin link ./plugins/pstack
```

Check that discovery worked in a fresh session:

```
omp -p --no-session --thinking off "Do not call any tool. List every agent name in the task tool's Available Agents section."
```

Expect `pstack_fast`, `pstack_judgment`, `pstack_panel_1` through `pstack_panel_4`, `poteto-agent`, and
`comment-sicko` among the bundled agents.

## Pin the router

`/poteto-mode on`, `/poteto-mode off`, and `/poteto-mode status` set and show the pin for the current
session. `Alt+Shift+T` toggles it. For a headless run, use `omp -p --poteto '...'`, because print mode
has no slash dispatch. The pin lives in session entries. It is rebuilt from the active branch on
session start, branch switches, and tree navigation, and with no entry on the branch the `--poteto`
flag decides.

Three different things are easy to confuse:

- **Listing.** Some skills are hidden from the model's skill list: `omp-mechanics`, the 24
  `principle-*` leaves, and `make-bot-ui`. They stay loaded.
- **Explicit invocation.** A hidden skill is still readable through `skill://<name>` and, when skill
  commands are enabled, `/skill:<name>`. The pin and the playbooks read them this way.
- **Persistent pinning.** `/poteto-mode on` adds a reminder to every agent run until you turn it off.
  It does not change which skills are listed.

`make-bot-ui` is hidden because its Grok routine, secret, and webhook-waking steps are not supported
on omp. Read `skill://omp-mechanics/references/make-bot-ui-on-omp.md` before using it for anything.

## Model routing

Model choice is one settings record, `task.agentModelOverrides`, mapping an exact agent name to a
concrete model selector. The six shipped agents carry no model of their own:

| Agent | Used for |
|---|---|
| `pstack_fast` | fast code and mechanical work: explorers, investigators, swarm workers, delegated implementers |
| `pstack_judgment` | judgment and prose: explainers, synthesizers, reviews, the hardest delegated tasks |
| `pstack_panel_1` to `pstack_panel_4` | diverse-model panel slots: arena, architect, interrogate, reflect divergent, swarm race arms |

Run `/skill:setup-pstack` to configure it. Setup reads `omp models --json`, writes only these six
keys into the effective user configuration, preserves every other entry, and removes a key when you
choose to inherit. An unconfigured agent inherits the parent's model, and an unconfigured panel still
runs two independent contexts, though without a promise of different models. Retry fallbacks and
extension routing can still change the final model, so check the resolved model each result reports.
Setup does not change your chat model, and new task launches use the values without a restart.

`references/setup-pstack-config.md` in `omp-mechanics` is the authoritative format. Vibe workers
expose only `fast` and `good`, so per-role task routing is unavailable there.

## What differs from upstream

Every Cursor mechanic is substituted for its omp equivalent.

- **Isolation.** Cloud agents become local `isolated: true` subagents when `task.isolation.enabled`
  is on and plan mode is off. A kept-alive isolated agent keeps its workspace through idle and
  parked states and revives in-process on a direct message. After a host restart it cannot be
  cold-revived, so reconcile durable artifacts and dispatch replacement work.
- **Coordination.** Agent and job coordination uses `read history://`, `read proc://`, `write` to
  `agent://<id>`, named `bash` services, and the `wait` tool, which takes no arguments.
- **Scheduling.** A named service watches work only while its session exists. There is no shipped
  routine or webhook service. For unattended runs, connect launchd on macOS or a systemd user timer
  or cron on Linux to an explicit CLI or authenticated RPC entry point.
- **Transcripts.** Cursor transcripts become the omp session store, resolved through
  `references/session-store-on-omp.md`.
- **Models.** No skill names a vendor model. Name a capability, route it with
  `task.agentModelOverrides`, and pick the chat model with `/model`.

`PORTING.md` at the repo root records every substitution and the re-sync procedure.

## Optional agents

`poteto-agent` ships model-free and inherits your chat model. It and `comment-sicko` are used only
when the live roster lists them; otherwise `skill://pstack-omp` maps the role to an available worker.
