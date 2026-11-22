import { spawn } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const exe = join(here, "..", "bin", "QoderComputerUse.exe");
const closeOnly = process.argv.includes("--close-only");

const env = {
  ...process.env,
  QODER_CUA_OPERATION_OVERLAY: "0",
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

async function findCalculator(timeoutMs = 20000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const result = await callTool("list_windows", { refresh: true });
    const list = payload(result).result || [];
    const match = list.find((w) => /^Calculator$/i.test(w.title || ""));
    if (match) return match;
    await sleep(400);
  }
  throw new Error("Calculator window not found");
}

async function main() {
  await send("initialize", {
    protocolVersion: "2024-11-05",
    capabilities: {},
    clientInfo: { name: "computer-use-demo", version: "1.0.0" },
  });
  child.stdin.write(JSON.stringify({ jsonrpc: "2.0", method: "notifications/initialized" }) + "\n");

  const window = await findCalculator();
  const win = { app: window.app, id: window.id };

  if (closeOnly) {
    await callTool("activate_window", { window: win, verify_foreground: true });
    await callTool("press_key", { window: win, key: "Alt_L+F4" });
    log("closed Calculator");
    return;
  }

  log("Computer Use MCP - live demo");
  log("----------------------------------------");
  log("[1] initialize -> ok");
  await sleep(400);
  log('[2] list_windows -> found "Calculator"');
  await sleep(600);

  await callTool("activate_window", { window: win, verify_foreground: true });
  log("[3] activate_window -> ok");
  await sleep(600);

  const stateResult = payload(
    await callTool("get_window_state", { window: win, include_screenshot: true, include_text: false })
  );
  const state = stateResult.result || {};
  const shot = (state.screenshots || [])[0] || {};
  log(`[4] get_window_state -> ${shot.width || "?"}x${shot.height || "?"}`);
  await sleep(600);

  await callTool("press_key", { window: win, key: "Escape" });
  await sleep(300);

  const steps = [
    { tool: "click", arguments: { element_text: "Seven" } },
    { tool: "click", arguments: { element_text: "Multiply by" } },
    { tool: "click", arguments: { element_text: "Eight" } },
    { tool: "click", arguments: { element_text: "Equals" } },
  ];

  const batchResult = payload(
    await callTool("run_steps", {
      window: win,
      steps,
      post_step_sleep_ms: 650,
      final_state: true,
      final_state_include_screenshot: true,
      final_state_include_text: true,
      final_state_expect_text: "56",
      final_state_poll_attempts: 8,
    })
  );
  const batchOk = batchResult.ok !== false;
  log(`[5] run_steps (7 x 8 = 56) -> 4 steps, ${batchOk ? "ok" : "failed"}`);
  await sleep(1200);

  const finalResult = payload(
    await callTool("get_window_state", { window: win, include_text: true, include_screenshot: true })
  );
  const finalState = finalResult.result || {};
  const tree = finalState.accessibility?.tree || "";
  const verified = /\b56\b/.test(tree);
  log(`[6] final state -> display shows 56: ${verified ? "yes" : "no"}`);
  await sleep(1400);

  log("----------------------------------------");
  log("DEMO COMPLETE - all UI actions via MCP");
  log("No overlay or pointer animation was drawn.");
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
