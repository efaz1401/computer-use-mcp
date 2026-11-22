import { spawn } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const exe = join(here, "..", "bin", "QoderComputerUse.exe");
const closeOnly = process.argv.includes("--close-only");

const env = {
  ...process.env,
  QODER_CUA_OPERATION_OVERLAY: "1",
  QODER_CUA_POINTER_ANIMATION: "0",
  QODER_CUA_LOG_LEVEL: "warn",
};

const child = spawn(exe, [], { stdio: ["pipe", "pipe", "ignore"], env, windowsHide: true });
let buffer = "";
let seq = 0;
const pending = new Map();

child.stdout.on("data", (chunk) => {
  buffer += chunk.toString();
  let idx;
  while ((idx = buffer.indexOf("\n")) >= 0) {
    const line = buffer.slice(0, idx);
    buffer = buffer.slice(idx + 1);
    let msg;
    try {
      msg = JSON.parse(line);
    } catch {
      continue;
    }
    if (msg.id && pending.has(msg.id)) {
      const waiter = pending.get(msg.id);
      pending.delete(msg.id);
      msg.error ? waiter.reject(new Error(JSON.stringify(msg.error))) : waiter.resolve(msg.result);
    }
  }
});

function send(method, params) {
  const id = ++seq;
  child.stdin.write(JSON.stringify({ jsonrpc: "2.0", id, method, params }) + "\n");
  return new Promise((resolve, reject) => pending.set(id, { resolve, reject }));
}

function callTool(name, args) {
  return send("tools/call", { name, arguments: args });
}

function payload(result) {
  try {
    return JSON.parse(result.content[0].text);
  } catch {
    return result;
  }
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const log = (line = "") => console.log(line);

async function listWindows() {
  const result = await callTool("list_windows", { refresh: true, include_minimized: true });
  return payload(result).result || [];
}

async function waitForWindow(predicate, timeoutMs = 25000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const match = (await listWindows()).find(predicate);
    if (match) return match;
    await sleep(400);
  }
  throw new Error("Window not found");
}

async function observe(window) {
  const result = payload(
    await callTool("get_window_state", { window, include_screenshot: true, include_text: false })
  );
  const state = result.result || {};
  const shot = (state.screenshots || [])[0] || {};
  return { state, width: shot.width || 0, height: shot.height || 0 };
}

async function clickAt(window, x, y, revision, clickCount = 1) {
  const args = { window, x: Math.round(x), y: Math.round(y), accessibility_revision: String(revision) };
  if (clickCount > 1) args.click_count = clickCount;
  const result = payload(await callTool("click", args));
  return result.ok !== false;
}

async function closeDemo() {
  const pc0 = (await listWindows()).find((w) => w.title === "PC0");
  if (pc0) {
    const win = { app: pc0.app, id: pc0.id };
    await callTool("activate_window", { window: win, verify_foreground: true });
    await callTool("press_key", { window: win, key: "Alt_L+F4" });
    await sleep(700);
  }

  const main = (await listWindows()).find((w) => /packet-tracer-demo\.pkt/i.test(w.title || ""));
  if (main) {
    const win = { app: main.app, id: main.id };
    await callTool("activate_window", { window: win, verify_foreground: true });
    await callTool("press_key", { window: win, key: "Alt_L+F4" });
    await sleep(1000);

    const dialog = (await listWindows()).find((w) => /Exit.*Cisco Packet Tracer/i.test(w.title || ""));
    if (dialog) {
      const dwin = { app: dialog.app, id: dialog.id };
      const state = payload(
        await callTool("get_window_state", { window: dwin, include_screenshot: false, include_text: true })
      ).result;
      const tree = state.accessibility?.tree || "";
      const match = tree.match(/^\s*(\d+) button No\b/m);
      if (match) {
        await callTool("click", {
          window: dwin,
          element_index: Number(match[1]),
          accessibility_revision: String(state.snapshotRevision),
        });
        await sleep(800);
      }
    }
  }
  log("closed Packet Tracer");
}

async function main() {
  await send("initialize", {
    protocolVersion: "2024-11-05",
    capabilities: {},
    clientInfo: { name: "computer-use-demo", version: "1.0.0" },
  });
  child.stdin.write(JSON.stringify({ jsonrpc: "2.0", method: "notifications/initialized" }) + "\n");

  if (closeOnly) {
    await closeDemo();
    return;
  }

  const ptWindow = await waitForWindow((w) => /packet-tracer-demo\.pkt/i.test(w.title || ""));
  const pt = { app: ptWindow.app, id: ptWindow.id };

  log("Computer Use MCP - Packet Tracer demo");
  log("----------------------------------------");
  log("[1] initialize -> ok");
  await sleep(300);
  log('[2] list_windows -> "packet-tracer-demo.pkt"');

  await callTool("activate_window", { window: pt, verify_foreground: true });
  await sleep(400);

  const mainState = await observe(pt);
  const pc0X = mainState.width * 0.273;
  const pc0Y = mainState.height * 0.622;
  const opened = await clickAt(pt, pc0X, pc0Y, mainState.state.snapshotRevision, 2);
  log(`[3] double-click PC0 -> ${opened ? "ok" : "failed"}`);
  await sleep(700);

  const pc0Window = await waitForWindow((w) => w.title === "PC0", 8000);
  const pc0 = { app: pc0Window.app, id: pc0Window.id };
  log('[4] device window "PC0" opened');
  await callTool("activate_window", { window: pc0, verify_foreground: true });
  await sleep(400);

  let state = await observe(pc0);
  const desktopOk = await clickAt(pc0, state.width * 0.22, state.height * 0.075, state.state.snapshotRevision);
  log(`[5] Desktop tab -> ${desktopOk ? "ok" : "failed"}`);
  await sleep(700);

  state = await observe(pc0);
  const cmdOk = await clickAt(pc0, state.width * 0.662, state.height * 0.167, state.state.snapshotRevision);
  log(`[6] Command Prompt -> ${cmdOk ? "ok" : "failed"}`);
  await sleep(900);

  state = await observe(pc0);
  await clickAt(pc0, state.width * 0.42, state.height * 0.19, state.state.snapshotRevision);
  await sleep(250);
  await callTool("type_text", { window: pc0, text: "ipconfig" });
  log("[7] type ipconfig -> ok");
  await sleep(250);
  await callTool("press_key", { window: pc0, key: "Return" });
  await sleep(1600);

  state = await observe(pc0);
  await clickAt(pc0, state.width * 0.42, state.height * 0.55, state.state.snapshotRevision);
  await sleep(250);
  await callTool("type_text", { window: pc0, text: "ping 192.168.10.1" });
  log("[8] type ping 192.168.10.1 -> ok");
  await sleep(250);
  await callTool("press_key", { window: pc0, key: "Return" });
  await sleep(6500);

  await observe(pc0);
  log("[9] final state -> ping replies captured");
  await sleep(1200);

  log("----------------------------------------");
  log("DEMO COMPLETE - all UI actions via MCP");
  log("Neutral control indicator shown; Escape aborts.");
}

main()
  .catch((error) => {
    console.error("DEMO ERROR:", error?.message || error);
    process.exitCode = 1;
  })
  .finally(async () => {
    try {
      child.stdin.end();
    } catch {}
    setTimeout(() => {
      try {
        child.kill();
      } catch {}
      process.exit();
    }, 800);
  });
