import { expect, test } from "bun:test";
import potetomode from "./index.js";

const entry = (pinned) => ({ type: "custom", customType: "poteto-mode", data: { pinned } });

function host(flag = true) {
  const events = new Map();
  let command, shortcut, entries = [], status = "", appended = 0;
  const ctx = {
    sessionManager: { getBranch: () => entries },
    ui: { theme: { fg: (_color, text) => text }, setStatus: (_key, value) => { status = value; }, notify() {} },
  };
  potetomode({
    registerCommand: (_name, value) => { command = value.handler; },
    registerFlag() {},
    registerShortcut: (_name, value) => { shortcut = value.handler; },
    on: (name, handler) => events.set(name, handler),
    getFlag: () => flag,
    appendEntry: (_name, data) => { appended++; entries.push(entry(data.pinned)); },
    sendUserMessage() {},
  });
  const fire = async (name, branch) => {
    if (branch) entries = branch;
    await events.get(name)({}, ctx);
  };
  return {
    start: (branch = []) => fire("session_start", branch),
    branch: (branch) => fire("session_branch", branch),
    tree: (branch) => fire("session_tree", branch),
    agentStart: () => fire("agent_start"),
    agentEnd: () => fire("agent_end"),
    before: (systemPrompt = ["original"]) => events.get("before_agent_start")({ systemPrompt }),
    command: (args) => command(args, ctx),
    shortcut: () => shortcut(ctx),
    status: () => status,
    appended: () => appended,
  };
}

const pinnedNow = async (session) => (await session.before()) !== undefined;

test("persisted explicit off survives a restart with --poteto", async () => {
  const session = host();
  await session.start([entry(false)]);
  expect(await session.before()).toBeUndefined();
});

test("--poteto still enables a session without a saved override", async () => {
  const session = host();
  await session.start();
  expect((await session.before()).systemPrompt[1]).toContain("poteto-mode is PINNED");
});

test("malformed stored booleans never activate the pin", async () => {
  const session = host();
  for (const pinned of ["false", 1, null, undefined]) {
    await session.start([entry(pinned)]);
    expect(await session.before()).toBeUndefined();
    await session.branch([entry(pinned)]);
    expect(await session.before()).toBeUndefined();
    await session.tree([entry(pinned)]);
    expect(await session.before()).toBeUndefined();
  }
});

test("latest entry wins and a new session resets the previous override", async () => {
  const session = host();
  await session.start([entry(true), entry(false)]);
  expect(await session.before()).toBeUndefined();
  await session.start();
  expect(await session.before()).toBeDefined();
  await session.start([entry(false), entry(true)]);
  expect(await session.before()).toBeDefined();
});

test("branch and tree navigation restore the pin from the active branch", async () => {
  for (const nav of ["branch", "tree"]) {
    const session = host(false);
    await session.start();
    expect(await pinnedNow(session)).toBe(false);
    await session[nav]([entry(true)]);
    expect(await pinnedNow(session)).toBe(true);
    expect(session.status()).toContain("PINNED");
    await session[nav]([entry(true), entry(false)]);
    expect(await pinnedNow(session)).toBe(false);
    expect(session.status()).toBe("");
    await session[nav]([entry(false), entry(true)]);
    expect(await pinnedNow(session)).toBe(true);
  }
});

test("navigating to an empty branch falls back to the flag for either value", async () => {
  for (const nav of ["branch", "tree"]) {
    const on = host(true);
    await on.start([entry(false)]);
    expect(await pinnedNow(on)).toBe(false);
    await on[nav]([]);
    expect(await pinnedNow(on)).toBe(true);

    const off = host(false);
    await off.start([entry(true)]);
    expect(await pinnedNow(off)).toBe(true);
    await off[nav]([]);
    expect(await pinnedNow(off)).toBe(false);
    expect(off.status()).toBe("");
  }
});

test("navigation reads the branch without appending a session entry", async () => {
  const session = host();
  await session.start([entry(false)]);
  await session.branch([entry(true)]);
  await session.tree([entry(false)]);
  expect(session.appended()).toBe(0);
});

test("a running agent stays active across navigation; a new session resets it", async () => {
  for (const nav of ["branch", "tree"]) {
    const session = host();
    await session.start();
    expect(session.status()).toContain("○");
    await session.agentStart();
    expect(session.status()).toContain("●");
    await session[nav]([entry(true)]);
    expect(session.status()).toContain("●");
    await session.agentEnd();
    expect(session.status()).toContain("○");
  }
  const session = host();
  await session.start();
  await session.agentStart();
  await session.start();
  expect(session.status()).toContain("○");
});

test("shortcut, status, command and injection share one effective state", async () => {
  const session = host();
  await session.start();
  expect(session.status()).toContain("PINNED");
  session.shortcut();
  expect(session.status()).toBe("");
  expect(await session.before()).toBeUndefined();
  await session.command("on");
  expect(session.status()).toContain("PINNED");
  expect(await session.before()).toBeDefined();
  await session.command("off");
  expect(await session.before()).toBeUndefined();
});

test("on/off transitions persist and are the entries navigation restores", async () => {
  const session = host(false);
  await session.start();
  await session.command("on");
  await session.command("off");
  await session.command("on");
  expect(session.appended()).toBe(3);
  await session.tree();
  expect(await pinnedNow(session)).toBe(true);
  await session.command("off");
  await session.branch();
  expect(await pinnedNow(session)).toBe(false);
});

test("prompt block boundaries and input blocks remain intact", async () => {
  const session = host();
  await session.start();
  const blocks = ["first", "second"];
  const result = await session.before(blocks);
  expect(result.systemPrompt.slice(0, 2)).toEqual(blocks);
  expect(blocks).toEqual(["first", "second"]);
  expect(result.systemPrompt).toHaveLength(3);
});
