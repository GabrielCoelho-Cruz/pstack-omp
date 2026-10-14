---
name: reflect
description: Spawn three parallel review subagents over the active transcript, surface learnings, and route each to a concrete edit on an existing skill. Use when the user says reflect.
---

# Reflect

Mine the current conversation for durable learnings, then route them into skill edits.

Invoke when the user says "reflect" or "/skill:reflect". Skip when the conversation is trivial, off-topic, or already covered by an existing skill the parent followed correctly. One-offs are not learnings.

## 1. Locate the active transcript

Before fanning out, read `skill://omp-mechanics/references/session-store-on-omp.md` and resolve the active session root as it directs. Do not assume a default root, and stay inside the authorized workspace. Take the live session's own transcript path when the runtime reports one. Otherwise scan only the bucket for the current project under the resolved root. Do not glob sibling project buckets. That crosses workspace boundaries and reads private chats from unrelated projects.

omp writes one layout: a flat `<timestamp>_<session-id>.jsonl` per session in the bucket, with `<AgentId>.jsonl` sidecars in the sibling directory named for that stem. The first line of an omp transcript is a fixed-width `type:title` slot and the second a `type:session` header, neither of them a message. Take the file whose first `type:message` line with `role:user` contains the conversation's opening user prompt. If none matches, pass a tight digest of the session instead.

## 2. Spawn three reviewers in parallel

Spawn the three reviewers together through `skill://pstack-omp`, in the batch or flat shape the live `task` schema accepts, each on its own exact agent below. Setup's model choices reach each spawn through that agent, as described in `skill://omp-mechanics/references/setup-pstack-config.md`. Every spawn keeps the runtime's normal tools, because reviewers need MCP access to look up the tickets, chat threads, and observability traces the transcript references. Read-only posture is stated in each brief and is not a sandbox. Each brief tells the reviewer to start no subagents and to finish through `yield` with its findings. Every task item carries a `solutionSpace`. Leave each subagent's thinking to its route, per the Subagents section of the **poteto-mode** skill.

| Lens | `agent` | Prompt template |
|---|---|---|
| Judgment | `pstack_judgment` | `references/judgment-reviewer.md` |
| Tooling | `pstack_fast` | `references/tooling-reviewer.md` |
| Divergent | `pstack_panel_2` | `references/divergent-reviewer.md` |

Configured Divergent should be a different model family from Judgment. After the reviewers return, compare their returned resolved models and fallback flags. When Divergent and Judgment ran on the same model, or the metadata cannot show a difference, say so in the report. Never assume diversity. If discovery blocks an agent name, report the unavailable configured route. Never fall back to the generic worker and claim setup took effect.

Pass each template verbatim, substituting the transcript path or digest where marked. Reviewers return findings in the `Task` response body.

## 3. Synthesize

One task item on `pstack_judgment`, with a `solutionSpace` and the runtime's normal tools so it can spot-verify citations through MCP. Its brief states read-only posture, no subagents, and finishing through `yield`. Pass `references/synthesizer.md` verbatim, with each reviewer's full output inlined where marked. It returns an Accepted / Rejected / Backlog list.

## 4. Structural enforcement check

Move any Accepted item that a lint rule, script, metadata flag, or runtime check would enforce more reliably to Backlog. See the **encode-lessons-in-structure** principle skill.

## 5. Apply

Present the synthesizer's full Accepted / Rejected / Backlog output and wait for explicit approval before applying any Accepted edit. The user picks the subset and may redirect routings. Skill changes affect every future agent in the org. Do not auto-apply.

File each Backlog item to your team's devex or backlog tracker without waiting. Only the Accepted list waits for approval.

Follow each approved row's Routing exactly:

- Trivial existing-skill edit (a one-line bullet, a tightened sentence, a stale fact corrected): the parent does it directly.
- Substantive existing-skill edit (a new section, a new pattern table, more than ~10 lines): read `skill://poteto-mode/playbooks/authoring-a-skill.md` and run its draft / test / iterate loop.
- `tune description: <skill path>` (the skill exists but didn't trigger when it should have): read `skill://poteto-mode/playbooks/authoring-a-skill.md` and run its description-optimization loop.
- `new skill via authoring-a-skill: <kebab-name>`: read `skill://poteto-mode/playbooks/authoring-a-skill.md` and create the skill through it. Do not invent the shape ad hoc.

Run the playbook's check step on every touched skill, and any SKILL.md validator your environment ships, before declaring done.

## 6. Summarize for the user

Short list, no preamble:

- Edits applied: `<skill path>`. What changed, one line each.
- New skills created: `<skill path>`. One line each (rare).
- Backlog filed to the devex tracker: `<issue title>` (`<tags>`). One line each.
- Dropped: one line per rejected finding + reason from the synthesizer.
