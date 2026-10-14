# pstack-omp

An omp marketplace carrying two plugins.

`pstack` is the pstack engineering methodology for Cursor, ported to oh-my-pi and made model and
provider agnostic: 55 skills with 23 playbooks and 24 principle leaves, a `poteto-mode` pin, and 8
agents. Six of the agents are model-free routing slots that `/skill:setup-pstack` binds to concrete
models, the other two are `poteto-agent` and `comment-sicko`. `fan-out` is a small omp-native skill
for wide parallel runs. Its measurements are kept as historical observations, not as reliability
rules.

Install from a local checkout, or from a published URL of this marketplace:

```
/marketplace add <checkout-or-marketplace-url>
/marketplace install pstack@pstack-omp
/marketplace install fan-out@pstack-omp
/reload-plugins
```

The marketplace install ships each plugin's `skills/` and `agents/` directories, so the routing agents
are discovered with no symlink or extra provider. Restart omp once after the first install so the
`potetomode` extension module loads. `plugins/pstack/README.md` covers the pin, hidden skills, and
how a fresh session proves discovery.

Model routing is one setting, `task.agentModelOverrides`, keyed by the six agent names. Run
`/skill:setup-pstack` to write it. An unconfigured agent inherits the parent model, and setup never
changes your chat model. Vibe workers expose only `fast` and `good`, so per-role task routing is not
available there.

The pin is `omp-port/UPSTREAM`, the full sha of the `cursor/plugins` commit the port is built from.
The catalog names its short form. `PORTING.md` is the full porting record: how the tree is built,
installed, versioned, and re-synced. `omp-port/check-port.sh` is the gate every change passes before
release. The port keeps its own stable version counter, so a port-only change releases with
`bash omp-port/sync-upstream.sh release`.

Licensed MIT, same as upstream. The copyright and attribution notices are in `LICENSE` and
`THIRD_PARTY_NOTICES.md`, and each plugin ships them.
