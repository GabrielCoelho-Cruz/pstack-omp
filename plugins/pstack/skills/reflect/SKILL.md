---
name: reflect
description: Spawn three parallel review subagents over the active transcript, surface learnings, and route each to a concrete edit on an existing skill. Use when the user says reflect.
---

# Reflect

Mine the current conversation for durable learnings, then route them into skill edits.

Invoke when the user says "reflect" or "/reflect". Skip when the conversation is trivial, off-topic, or already covered by an existing skill the parent followed correctly. One-offs are not learnings.

## 1. Locate the active transcript

Before fanning out, find this conversation's transcript in the `agent-transcripts/` directory the system prompt names. Do not glob across sibling `~/.omp/agent/sessions/<other-cwd>/` buckets. That crosses workspace boundaries and reads private chats from unrelated projects.

```bash
ls -t ~/.omp/agent/sessions/<encoded-cwd>/*.jsonl ~/.omp/agent/sessions/<encoded-cwd>/*/*.jsonl ~/.omp/agent/sessions/<encoded-cwd>/*/subagents/*.jsonl 2>/dev/null | head -10
```

omp writes one layout: a flat `<timestamp>_<session-id>.jsonl` per session in the bucket, with `<AgentId>.jsonl` sidecars in the sibling directory named for that stem. The first line of an omp transcript is a fixed-width `type:title` slot and the second a `type:session` header, neither of them a message. Take the file whose first `type:message` line with `role:user` contains the conversation's opening user prompt. If none matches, pass a tight digest of the session instead.

## 2. Spawn three reviewers in parallel

One `task` call with three items in `tasks[]`, each `agent`: `task` (omp's general-purpose bundled agent) pinned by its own agent name, full tools per spawn. Run the three lenses on three different model families where `omp models` offers them, and keep Divergent on a different model family from Judgment, since the lens earns its name from different priors and not a different prompt. Reviewers need MCP access to look up the tickets, chat threads, and observability traces the transcript references. omp's task wire has no `readonly` field, so nothing strips them.

Each reviewer and the synthesizer name a role line in `task.agentModelOverrides` in `~/.omp/agent/config.yml` and a default. Set `model` to that line's value, or to the default if the rule or the line is missing. Leave `model` unset when the value is `auto` or `inherit-parent`. If the Task tool rejects a slug, use the default and say so. If it rejects the default, use the closest valid slug of the same family from its error message.

| Lens | Role line | Default `model` | Prompt template |
|---|---|---|---|
| Judgment | `reflect judgment, divergent, synthesizer` | your strongest judgment model | `references/judgment-reviewer.md` |
| Tooling | `reflect tooling` | your fast code model | `references/tooling-reviewer.md` |
| Divergent | `reflect judgment, divergent, synthesizer` | your strongest judgment model | `references/divergent-reviewer.md` |

Pass each template verbatim, substituting the transcript path or digest where marked. Reviewers return findings in the `Task` response body.

## 3. Synthesize

One `Task` call, `agent`: `task` (omp's general-purpose bundled agent), `model` from the `reflect judgment, divergent, synthesizer` line (default your strongest judgment model), full tools per spawn. It spot-verifies citations through MCP. omp's task wire has no `readonly` field, so nothing strips them. Pass `references/synthesizer.md` verbatim, with each reviewer's full output inlined where marked. It returns an Accepted / Rejected / Backlog list.

## 4. Structural enforcement check

Move any Accepted item that a lint rule, script, metadata flag, or runtime check would enforce more reliably to Backlog. See the **encode-lessons-in-structure** principle skill.

## 5. Apply

Present the synthesizer's full Accepted / Rejected / Backlog output and wait for explicit approval before applying any Accepted edit. The user picks the subset and may redirect routings. Skill changes affect every future agent in the org. Do not auto-apply.

File each Backlog item to your team's devex or backlog tracker without waiting. Only the Accepted list waits for approval.

Follow each approved row's Routing exactly:

- Trivial existing-skill edit (a one-line bullet, a tightened sentence, a stale fact corrected): the parent does it directly.
- Substantive existing-skill edit (a new section, a new pattern table, more than ~10 lines): hand to the `authoring-a-skill` playbook and run its draft / test / iterate loop.
- `tune description: <skill path>` (the skill exists but didn't trigger when it should have): hand to the `authoring-a-skill` playbook and run its description-optimization loop.
- `new skill via authoring-a-skill: <kebab-name>`: hand creation to the `authoring-a-skill` playbook. Do not invent the shape ad hoc.

If your environment ships a SKILL.md validator, run it on every touched skill before declaring done.

## 6. Summarize for the user

Short list, no preamble:

- Edits applied: `<skill path>`. What changed, one line each.
- New skills created: `<skill path>`. One line each (rare).
- Backlog filed to the devex tracker: `<issue title>` (`<tags>`). One line each.
- Dropped: one line per rejected finding + reason from the synthesizer.
