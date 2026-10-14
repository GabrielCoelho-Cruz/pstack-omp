---
name: no-comments
description: "Spawn Comment Sicko, fix accepted findings, and offer encodings for claimed constraints."
---

# No comments

Start one comment review. Resolve the report-only auditor through `skill://pstack-omp` (canonical
role resolution) against the live roster. `comment-sicko` is the optional bundled target. When it is
absent, give an available worker the role and file-pointer instructions as a brief only. Only pass
fields the live `task` schema exposes. The auditor edits nothing. This skill's caller applies every deletion.

Defer to the auditor's fresh perspective.

## Scope

Use the caller's files or diff. Otherwise use the current diff against the base branch, default `main`, including the working tree.

## Steps

1. Spawn the resolved auditor with the scope. Pick each subagent's reasoning `effort` for the job when the live `task` schema exposes it, per the Subagents section of the **poteto-mode** skill. Do not restate its rules. It returns proposed deletions, retained exceptions, and code flagged for investigation. It edits nothing.
2. Examine its proposals yourself. Reject proposals that touch application code, escape the scope, delete exception-protected comments, misstate `MUST KILL` reasons, or treat kept intentional code as guilty. Reshape flags on our-code surprises stay actionable, so do not keep those comments. A keep survives only with proof it is about something we cannot change. Audit missed scoped lint and TypeScript suppressions. Correctness or safety suppressions stay actionable `MUST KILL`s. Before accepting thin `IMPORTANT` or `do not remove` kills or keeps, and for every `NEEDS_PARENT_INVESTIGATION` flag, run `/skill:how` or `/skill:why` on the symbol yourself. If a kill is ambiguous, keep the comment. If a keep is refuted or still ambiguous, delete it. Apply the accepted deletions yourself. Ask the auditor again, with the failure named, for one rejected report. Reject a second, report it open, and fail `/skill:no-comments`. Never ask the auditor for a diff and never revert another worker's edits.
3. Fix trivial accepted flags directly by deleting a dead path, dropping a parameter, or using the real API. If any fix needs a shape, run `/skill:architect` once for the accepted set and surrounding code. Stop at the sketch. Architect shapes. Step 4 implements.
4. Implement the smallest root-cause fix in scope. Remove every named workaround. If the root cause is out of scope, land the smallest in-scope fix and report the rest open. The **principle-fix-root-causes** and **principle-redesign-from-first-principles** skills guide intent only. Neither authorizes widening the fence nor fixing instances outside it. Never bolt on symptom guards.
5. Constraint comments say `do not remove`, `do not change wording`, or `talk to X before changing`. Leave keeps about things we cannot change. Offer the cheapest in-scope type, runtime, test, or CI lint. Wait for interactive approval. Unattended and eval require caller pre-approval. If approved, encode then delete. Otherwise delete, report the constraint open, and sketch out-of-scope work.
6. Report the proposed deletion count and the count you applied, rejected proposals, reruns, architect sketch, fixes, encoding offers, encodings, unenforced constraints, and other open work.
