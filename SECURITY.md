# Security Policy

Computer Use MCP grants an AI model direct visual inspection and GUI input control over Windows desktop applications. Because desktop automation carries higher privilege than read-only APIs, treat security and user oversight as mandatory defaults.

## Built-In Safety Guardrails

1. **Local-Only `stdio` Transport:** The server communicates exclusively over standard input/output (`stdio`) JSON-RPC 2.0 with the local MCP host. It does not expose a network listening socket.
2. **Visible Control Indicator & Physical `Escape` Abort:**
   - Keep `QODER_CUA_OPERATION_OVERLAY=1` enabled so a visible amber screen-edge glow and status card appear whenever automated actions execute.
   - Pressing physical **`Escape`** immediately aborts control and returns `user_interrupted` to the host agent.
3. **Restricted OS Surfaces:**
   - The server rejects `Windows` / `Meta` / `Super` key chords.
   - Agent instructions in [`AGENTS.md`](AGENTS.md) forbid automating terminals, Windows Run dialogs, password managers, authentication prompts, or Windows security/privacy settings, and require explicit user confirmation before sensitive actions (sending messages, deleting files, uploading data, purchases, or permission changes).
4. **Indirect Prompt Injection Defense:**
   - Treat all text extracted from screenshots, UI Automation (UIA) trees, documents, chats, and web pages as **untrusted data**, never as executable instructions or permission grants.
   - Run unattended or experimental automation inside an isolated Windows Virtual Machine or dedicated low-privilege Windows user account.

## Binary Provenance & Open-Source Roadmap

- **Current State (`v2.2.16`):** This repository currently bundles a precompiled Windows binary (`bin/QoderComputerUse.exe`, SHA-256: `94CD280B3996C1851188EF8917F27A6B4974B090D87B15709CDB548951872EB3`) along with `tools/set-indicator.ps1`, which patches overlay strings/colors and clears the Authenticode directory entry.
- **Verify Before Running:** Check the file hash on Windows before executing:
  ```powershell
  Get-FileHash .\bin\QoderComputerUse.exe -Algorithm SHA256
  ```
- **Open-Source Native Rust Transition (In Progress):** We are replacing the bundled third-party binary with a 100% open-source native Rust Windows MCP server compiled transparently via GitHub Actions with checksummed release artifacts and no committed `.exe` blobs in Git.

## Reporting a Vulnerability

If you discover a security vulnerability, prompt-injection bypass, or unsafe input handling behavior:

1. **Do not** open a public issue with exploit details.
2. Submit a private report via [GitHub Security Advisories](https://github.com/efaz1401/computer-use-mcp/security/advisories/new).
3. Include reproduction steps, Windows version, MCP client name/version, and expected vs. observed behavior.
