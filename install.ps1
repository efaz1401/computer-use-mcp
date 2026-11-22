$ErrorActionPreference = "Stop"

$PluginDir = Join-Path $env:USERPROFILE ".gemini\config\plugins\efaz1401-computer-use"
$SourceDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if ($SourceDir -ne $PluginDir) {
    New-Item -ItemType Directory -Force -Path $PluginDir | Out-Null
    Copy-Item -Path "$SourceDir\*" -Destination $PluginDir -Recurse -Force -Exclude ".git"
}

$ExePath = Join-Path $PluginDir "bin\QoderComputerUse.exe"
if (-not (Test-Path $ExePath)) {
    throw "QoderComputerUse.exe not found at $ExePath"
}

$McpConfig = @{
    mcpServers = @{
        mcp = @{
            command = $ExePath
            args    = @()
            env     = @{
                QODER_CUA_IDE_PRODUCT       = "Antigravity"
                QODER_CUA_OPERATION_OVERLAY = "1"
                QODER_CUA_POINTER_ANIMATION = "0"
                QODER_CUA_LOG_LEVEL         = "warn"
            }
        }
    }
}

$McpConfigPath = Join-Path $PluginDir "mcp_config.json"
$McpConfig | ConvertTo-Json -Depth 5 | Set-Content -Path $McpConfigPath -Encoding UTF8

Write-Host "Installed efaz1401-computer-use plugin to: $PluginDir" -ForegroundColor Green
Write-Host "Bound MCP server binary: $ExePath" -ForegroundColor Cyan
