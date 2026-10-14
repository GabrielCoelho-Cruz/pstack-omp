# make-bot-ui on omp

Amends every step of **make-bot-ui**. Creating, storing, and waking a Grok routine is a Grok Bot
mechanic with no counterpart in this install. Read the marked steps as the upstream design, and
probe before claiming this harness can perform them. `omp --help` and the live tool schemas are the
check. If a later version grows a routine store or an inbound webhook, prefer it over anything here.
No replacement service ships with this plugin, and this reference does not promise one.

## Grok Bot only

None of this exists on omp. There is no routine store, no inbound webhook endpoint, and no card
that collects a secret without showing it in the transcript.

- Webhook routines, and the routine mechanic's `update_state` call.
- The routine panel that holds the URL and sender key, and the `api2.cursor.sh` endpoint.
- The `SendToUser` secret-request card.
- The `[routine]` wake turn, and every inbound webhook wake.

## Works here

The unsupported boundary is creating, storing, and waking a Grok routine. Serving an ordinary page
is not unsupported: the page, the local server that holds the key, the outbound POST, the Tailscale
exposure, and every probe work here.

Run the server as a named `bash` service: a project-unique `name`, the `command`, an optional `cwd`,
and a `ready` condition on its log line or port so readiness is observed rather than assumed. Do not
combine `name` with `async` or a supplied `timeout`; when both `ready.log` and `ready.port` are
given, both must pass. Read its status and output with `read proc://<service-name>`, send stdin with
`write proc://<service-name>`, and stop it with `write proc://<id>/kill` and no content. Never
background it with a bare shell `&`. Probe it with the `browser` prelude in an `eval` cell or with
`curl`.

Serving a page and putting it on the tailnet is the whole job when the target is a plain HTTP
endpoint you already own. Reach for this skill for that half.

## Secrets

There is no card on omp that hides the value. `ask` puts whatever the user types into the
transcript, so never use it for a secret.

Name the config file the server reads, tell the user to write the key into it themselves, and never
read that file. Give them a `chmod 600` path under the UI's own directory. Read only whether the
file exists, not what is in it.

## Waking on new work

No routine or webhook service ships with omp, so nothing in this plugin pushes a turn from outside.
That does not make external prompts impossible: an authenticated RPC `prompt`, `steer`, or
`follow_up` call, or an extension, can inject work into a session. A named `bash` service observes
work only while its session exists. It is not an out-of-session scheduler by itself.

For unattended runs, use launchd on macOS or an available systemd user timer or cron on Linux,
connected to an explicit `omp -p` or authenticated RPC entry point. Do not silently substitute one
OS's scheduler for another. Any polling design makes its interval the latency floor. Do not invent a
loop grammar or cadence; inspect live loop help first.
