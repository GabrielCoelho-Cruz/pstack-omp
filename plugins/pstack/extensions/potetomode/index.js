// potetomode: the persistent pin for pstack's /poteto-mode.
//
// omp skills have no frontmatter that re-reminds the agent every turn, so this extension holds the
// pin. The pin state lives in "poteto-mode" custom session entries and is rebuilt from the active
// branch on session start, branch switches, and tree navigation. With no entry on the branch, the
// `--poteto` flag decides. The reminder is appended to the system prompt on each agent run; it is
// not a hidden-skill override and does not change what the skills themselves expose.
const ENTRY = "poteto-mode";

// Text injected into the system prompt while the pin is active.
const REMINDER =
  "poteto-mode is PINNED for this session.\n" +
  "Before acting on a new task: read `skill://poteto-mode` in full (including its Principles index), " +
  "then read `skill://omp-mechanics` for the omp-specific levers every pstack skill assumes, " +
  "match the request against its playbook table, and copy the matched playbook's steps verbatim into " +
  "your todo list as the first items. A step you skip stays listed with `skip: <reason>`.\n" +
  "Route delegation through `skill://pstack-omp` using the live tool schema and available roster. " +
  "Casual turns, or an explicit opt-out, do not need the playbook.";

export default function potetomode(pi) {
  let pinned = false;
  let isActive = false;

  const syncStatus = (c) => {
    if (!c?.ui?.setStatus) return;
    let theme;
    try {
      theme = c.ui.theme;
      if (!theme?.fg) return;
    } catch {
      return;
    }

    if (!pinned) {
      c.ui.setStatus("poteto-mode", "");
      return;
    }

    // Indicator matches ponytail's style: ● active, ○ idle
    const indicator = isActive ? theme.fg("accent", "●") : theme.fg("dim", "○");
    // 🥔 / 👑 poteto: PINNED
    const pill =
      indicator +
      " 🥔 " +
      theme.fg("muted", "poteto: ") +
      theme.fg("warning", "👑 PINNED");

    c.ui.setStatus("poteto-mode", pill);
  };

  const restore = (entries) => {
    // Latest entry on the branch wins; scan backwards so a later unpin sticks.
    for (let i = entries.length - 1; i >= 0; i--) {
      const e = entries[i];
      if (e?.type === "custom" && e?.customType === ENTRY) return e.data?.pinned === true;
    }
    return undefined;
  };
  const setPinned = (next, ctx) => {
    pinned = next;
    pi.appendEntry(ENTRY, { pinned });
    syncStatus(ctx);
    ctx?.ui?.notify?.(
      pinned ? "poteto-mode pinned for this session." : "poteto-mode unpinned.",
      "info"
    );
  };

  pi.registerCommand("poteto-mode", {
    description: "Pin pstack's poteto-mode router for this session (on|off|status; default: toggle on)",
    handler: async (args, ctx) => {
      const arg = args.trim().toLowerCase();
      if (arg === "status") {
        syncStatus(ctx);
        ctx?.ui?.notify?.(`poteto-mode: ${pinned ? "pinned" : "not pinned"}`, "info");
        return;
      }
      if (arg === "off" || arg === "unpin") return setPinned(false, ctx);
      setPinned(true, ctx);
      // A bare `/poteto-mode <task>` pins and also starts the work.
      const rest = args.trim();
      if (rest && !["on", "off", "pin", "unpin", "status"].includes(rest.toLowerCase())) {
        pi.sendUserMessage(rest, ctx?.isIdle?.() === false ? { deliverAs: "followUp" } : undefined);
      }
    },
  });

  // Print mode (`-p`) has no slash dispatch, so the flag is how a headless run starts pinned.
  pi.registerFlag("poteto", {
    description: "Pin pstack's poteto-mode for this run (works in -p print mode)",
    type: "boolean",
  });

  // Alt+Shift+T toggles the pin.
  pi.registerShortcut("alt+shift+t", {
    description: "Toggle poteto-mode pin",
    handler: (ctx) => setPinned(!pinned, ctx),
  });

  const reconstruct = (ctx) => {
    pinned = restore(ctx.sessionManager.getBranch()) ?? pi.getFlag?.("poteto") === true;
    syncStatus(ctx);
  };

  pi.on("session_start", async (_event, ctx) => {
    isActive = false;
    reconstruct(ctx);
  });

  // Navigation changes which entries are on the active branch, not whether an agent is running.
  pi.on("session_branch", async (_event, ctx) => reconstruct(ctx));
  pi.on("session_tree", async (_event, ctx) => reconstruct(ctx));

  pi.on("agent_start", async (_event, ctx) => {
    isActive = true;
    syncStatus(ctx);
  });

  pi.on("agent_end", async (_event, ctx) => {
    isActive = false;
    syncStatus(ctx);
  });

  pi.on("before_agent_start", async (event) => {
    if (!pinned) return;
    // systemPrompt is an ordered block list; append a block rather than joining the list into a
    // string, which would collapse the provider's cache segmentation.
    return { systemPrompt: [...event.systemPrompt, REMINDER] };
  });
}
