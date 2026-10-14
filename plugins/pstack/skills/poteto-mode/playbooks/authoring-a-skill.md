### Authoring or modifying a skill

**You own the skill's voice.**

1. Write the SKILL.md yourself with `write` or `edit`. Place the skill as a directory directly under a skills root, never nested deeper, and name the directory exactly the frontmatter `name`. Give it YAML frontmatter with `name`, a `description` naming what the skill does and when to reach for it, and `disable-model-invocation: true` so it stays out of the per-turn index. The description is a YAML scalar. Quote it when it contains a colon or other special characters.
2. Mind ownership. Managed skills live under `~/.omp/agent/managed-skills` and are written only through omp's `manage_skill`. Never edit a user-authored skill with `manage_skill`. Edit authored skills directly.
3. Draft, then loop on real use. Run a representative use of the skill, check the outcome against what you wanted, and revise the text. Repeat until the outcome holds.
4. Loop on the description. Write a few positive prompts that should trigger the skill and a few near-miss prompts that should not. Check which ones trigger it, and revise the description until the positives fire and the near-misses stay quiet.
5. Validate the skill: frontmatter has `name` and `description`, referenced files exist, cross-skill links resolve.
6. Test cases if structural. Skip if subjective.
7. Run **Opening a PR**.

When in doubt, delete. Keep only prose that changes a decision. Tell it to do the thing and skip the reason. Explain only when the rule is confusing without one. Match tone to scope. Point at structural sources (types, READMEs, config) per the **encode-lessons-in-structure** principle skill. Delegate to other skills by path. Don't restate. A workflow you keep hitting but isn't captured → propose a new skill.

**Reply:** summary of the skill, key design decisions, validation notes.
