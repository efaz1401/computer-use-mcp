# Computer Use MCP — Native Windows MCP Server & Antigravity Plugin

Self-contained Antigravity plugin and universal MCP package bundling a native Rust Windows Computer Use executable (`bin/QoderComputerUse.exe`, `v2.2.16`) and an agent-agnostic `SKILL.md`.

The server needs no Node.js, Python, `node_repl`, or IDE running. Agent-facing usage instructions live in [AGENTS.md](AGENTS.md).

## Demo

[Watch the 30-second demo](demo/computer-use-demo.mp4): the MCP server opens the Packet Tracer project, opens PC0, runs `ipconfig`, and pings the gateway (`192.168.10.1`) with 4/4 replies — with a neutral control indicator visible while it acts.

To re-record it (Windows, Node.js, ffmpeg, Cisco Packet Tracer 9.0.1), run:

```powershell
powershell -ExecutionPolicy Bypass -File demo/record-demo.ps1
```

The recorder expects Packet Tracer at `C:\Program Files\Cisco Packet Tracer 9.0.1\bin\PacketTracer.exe`; adjust `$packetTracer` in the script if yours differs. The automation script is [demo/demo.mjs](demo/demo.mjs); the demo topology is [demo/packet-tracer-demo.pkt](demo/packet-tracer-demo.pkt).

## Control Indicator

The server shows a neutral, unbranded indicator while it is acting: a dark status card with an amber screen-edge glow and a physical `Escape` abort. It hides when control stops.

Customize the label (1-95 UTF-8 bytes):

```powershell
powershell -ExecutionPolicy Bypass -File tools/set-indicator.ps1 -Text "Computer Use active - Esc to cancel"
```

---

## Why Use `QoderComputerUse.exe` Directly?

Inside the upstream IDE integration, Computer Use is hidden behind a `node_repl` JavaScript wrapper (`@qoder-space/computer-use` / `@ali/qoder-cu-sdk`) that strips out several native features. Connecting directly to `bin/QoderComputerUse.exe` over stdio JSON-RPC 2.0 MCP unlocks:

- **All 14 Native Rust Tools** — including the hidden **`run_steps`** server-side 64-step batch orchestrator.
- **Single-Round-Trip Action + Refresh (`post_action_state: true`)** — every mutating tool can capture and return the updated screenshot and UIA tree in the same MCP call.
- **Semantic `element_text` Targeting** — `run_steps` can click, set values, or invoke secondary actions by matching control text directly without needing a separate `get_window_state` round-trip.
- **Server-Side UIA Tree Filtering (`state_tree_filter`, `state_max_tree_lines`)** — trims huge Electron/Chromium accessibility trees in Rust before returning to the model.
- **3-Tier Occluded Window Capture** — isolated child-process WinRT `Windows.Graphics.Capture` (compositing transient owned popups/menus) → GDI `PrintWindow` fallback → screen `BitBlt` fallback.
- **Neutral Control Indicator** — a dark status card with an amber screen-edge glow appears while actions run (`QODER_CUA_OPERATION_OVERLAY=1`), and physical `Escape` aborts control. Pointer animation stays off (`QODER_CUA_POINTER_ANIMATION=0`). Customize the label with `tools/set-indicator.ps1`.

---

## Repository Layout

```text
computer-use-mcp/
├── plugin.json                            # Antigravity plugin manifest
├── mcp_config.json                        # Antigravity MCP server config (qoder-computer-use_mcp)
├── install.ps1                            # Setup script that binds absolute binary path for any Windows user
├── AGENTS.md                              # Agent-facing usage instructions
├── bin/
│   └── QoderComputerUse.exe               # Native Rust MCP server (v2.2.16, x86_64 PE)
├── skills/
│   └── qoder-computer-use/
│       └── SKILL.md                       # Universal 14-tool MCP skill
├── demo/
│   ├── computer-use-demo.mp4              # 30-second Packet Tracer demo recording
│   ├── packet-tracer-demo.pkt             # Demo topology opened by the recording
│   ├── demo.mjs                           # MCP automation used in the demo
│   └── record-demo.ps1                    # Re-records the demo with ffmpeg
├── docs/
│   ├── reverse-engineering-report.md      # Full REA reverse-engineering dossier (27 Rust modules, 9 CLI flags, 29 env vars)
│   └── tools-schema.json                  # Complete JSON schemas for all 14 native MCP tools
└── assets/
    └── logo.svg
```

Tooling for the indicator lives in `tools/set-indicator.ps1`.

---

## Installation

### 1. Antigravity (Global Plugin)

Clone directly into `%USERPROFILE%\.gemini\config\plugins\qoder-computer-use` and run `install.ps1` to bind your user path:

```powershell
git clone https://github.com/efaz1401/computer-use-mcp.git "$env:USERPROFILE\.gemini\config\plugins\qoder-computer-use"
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.gemini\config\plugins\qoder-computer-use\install.ps1"
```

### 2. Claude Code CLI

```powershell
claude mcp add --scope user qoder-computer-use -- "$env:USERPROFILE\.gemini\config\plugins\qoder-computer-use\bin\QoderComputerUse.exe"
```

### 3. Claude Desktop / Cursor / Windsurf / VS Code (`mcp.json`)

```json
{
  "mcpServers": {
    "qoder-computer-use": {
      "command": "C:\\Users\\<YOU>\\.gemini\\config\\plugins\\qoder-computer-use\\bin\\QoderComputerUse.exe",
      "args": [],
      "env": {
        "QODER_CUA_OPERATION_OVERLAY": "1",
        "QODER_CUA_POINTER_ANIMATION": "0",
        "QODER_CUA_LOG_LEVEL": "warn"
      }
    }
  }
}
```

---

## Reverse-Engineering Documentation

See [docs/reverse-engineering-report.md](docs/reverse-engineering-report.md) for the complete REA (`reverse-engineer-anything`) investigation report covering all 27 Rust modules, 9 CLI flags, 29 `QODER_CUA_*` environment variables, and 4 stdio protocols, and [docs/tools-schema.json](docs/tools-schema.json) for the full 14-tool JSON schemas.
