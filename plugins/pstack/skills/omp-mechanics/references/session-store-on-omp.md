# The omp session store on disk

Amends **recall, reflect, eval, session-pickup, show-me-your-work, automate-me** in `SKILL.md`. Read
this before globbing for a transcript. Every path below came off a live store, so list a real bucket
before trusting this file after an upgrade.

## The root

Resolved, not fixed. **Resolve the effective storage directory before any scan** and never assume
`~/.omp/agent/sessions/`. The inputs, highest first, are the CLI `--session-dir` of the running
process, the `PI_CODING_AGENT_SESSION_DIR` environment variable, `PI_CODING_AGENT_DIR` for the
default profile, the active profile root (`--profile`, `OMP_PROFILE`, `PI_CONFIG_DIR`), and
`XDG_DATA_HOME`, which redirects only when its `omp` root already exists. A named profile ignores
`PI_CODING_AGENT_DIR` and sees only its own sessions. `omp config path` prints the agent directory in
effect, and the live session's own transcript path is the most direct anchor when one is reported.
Resolve once, then confirm by listing a real bucket. Stay inside the authorized workspace: scan only
the bucket for the current project, never sibling buckets.

## The bucket name

One bucket per canonicalized cwd, so two symlinked spellings of one directory share a bucket.

- A cwd under `$HOME` becomes the home-relative path with each `/` rewritten to `-`. The leading
  separator survives as a leading hyphen, so `/home/you/Desktop/proj` is `-Desktop-proj` and
  `/home/you/.omp/pstack` is `-.omp-pstack`.
- A cwd under the temp root becomes `-tmp-<rest>`.
- Anything else becomes `--<encoded-absolute>--`.

Two distinct paths that encode identically share one bucket, and 18.2.0 adds no digest to separate
them. A short-lived hashed scheme, `<scope>-<basename>-<sha256>`, shipped in 17.2.5 and was
reverted in 17.2.9. Old buckets in that form are migrated back to path-encoded names on access, so a
store with history may still show one.

## The files

One flat transcript per session, `<timestamp>_<session-id>.jsonl`. The timestamp is ISO-8601 with
its colons and its millisecond dot rewritten to hyphens, because a colon is path-hostile. A real
name, verbatim:

```
2026-09-08T08-48-08-964Z_01a08034-0904-74d7-ad70-398d79c17e89.jsonl
```

A sibling directory named with the same stem and no `.jsonl` is that session's artifact namespace.
It holds one `<AgentId>.jsonl` sidecar per direct child, each child's final output as `<AgentId>.md`
and `<AgentId>.json`, the `local://` scratch root, and one subdirectory per child that spawned
further. Files in those subdirectories carry the full dotted id:

```
<stem>/SliceA.jsonl
<stem>/SliceA.md
<stem>/Maintainer/Maintainer.SrcNav.jsonl
```

## Reading a transcript

Line 1 is a fixed-width 256-byte `type:title` slot, padded with spaces so a retitle rewrites in
place. It is not a message, and its title can diverge from the header's; the slot's title is the
live one. Line 2 is the `type:session` header carrying `id`, `timestamp`, `cwd`, and `title`. A
legacy file may start at the header.

To find the session that ran a given conversation, scan for the first `type:message` line with
`role:user` and match its text. Persisted roles are camelCase. A scan for `tool_result` finds
nothing, because the role is `toolResult`, and `toolCall` is a content block inside an assistant
message rather than a role.

`/clear` appends a durable `reset_boundary` entry. The model's context starts after the latest
boundary, but the file still holds everything before it, so a pickup reading the raw JSONL sees
material the previous agent could no longer see.

## Prefer the URIs

For a prior agent in this process, the internal URIs beat globbing. Bare `history://` lists registered
agents and transcripts with their status and parent. `history://<id>` renders one transcript and
takes line selectors, as in `history://<id>:1-50`. `agent://<id>` serves that agent's final output
artifact. A nested child's ID is dotted, so its output is `agent://Parent.Child`. A slash path is
always JSON extraction, as in `agent://Parent.Child/reports/0/data`; there is no `?q=` form. Read
`read proc://` for visible jobs and running agents. See [task](omp://tools/task.md).
