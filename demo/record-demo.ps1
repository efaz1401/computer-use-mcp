param(
  [string]$Output = (Join-Path $PSScriptRoot 'computer-use-demo.mp4')
)

$ErrorActionPreference = 'Stop'
$demoDir = $PSScriptRoot
$ffLog = Join-Path $demoDir 'ffmpeg.log'
$demoLog = Join-Path $demoDir 'demo.log'
$boldFont = Join-Path $demoDir '.demo-font-bold.ttf'
$font = Join-Path $demoDir '.demo-font.ttf'
$framesDir = Join-Path $demoDir '.frames'
$project = Join-Path $demoDir 'packet-tracer-demo.pkt'
$packetTracer = 'C:\Program Files\Cisco Packet Tracer 9.0.1\bin\PacketTracer.exe'

Copy-Item 'C:\Windows\Fonts\segoeuib.ttf' $boldFont -Force
Copy-Item 'C:\Windows\Fonts\segoeui.ttf' $font -Force

Add-Type -AssemblyName System.Drawing

Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class DemoWin {
  public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lp);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
}
"@

function Find-WindowLike([string]$Needle) {
  $script:found = [IntPtr]::Zero
  [DemoWin]::EnumWindows({
    param($h, $l)
    if ([DemoWin]::IsWindowVisible($h)) {
      $sb = New-Object System.Text.StringBuilder 512
      [void][DemoWin]::GetWindowText($h, $sb, 512)
      if ($sb.ToString() -like "*$Needle*") {
        $script:found = $h
        return $false
      }
    }
    return $true
  }, [IntPtr]::Zero) | Out-Null
  return $script:found
}

function Wait-WindowLike([string]$Needle, [int]$TimeoutSec = 45) {
  $deadline = (Get-Date).AddSeconds($TimeoutSec)
  while ((Get-Date) -lt $deadline) {
    $h = Find-WindowLike $Needle
    if ($h -ne [IntPtr]::Zero) { return $h }
    Start-Sleep -Milliseconds 300
  }
  throw "Window not found: $Needle"
}

$existing = Find-WindowLike 'packet-tracer-demo.pkt'
if ($existing -ne [IntPtr]::Zero) {
  $title = New-Object System.Text.StringBuilder 512
  [void][DemoWin]::GetWindowText($existing, $title, 512)
  throw "Close the open project first: $($title.ToString())"
}

Write-Host "Opening Packet Tracer..."
Start-Process -FilePath $packetTracer -ArgumentList ('"' + $project + '"') | Out-Null
$pt = Wait-WindowLike 'packet-tracer-demo.pkt' 60
[void][DemoWin]::ShowWindow($pt, 3)
[void][DemoWin]::SetForegroundWindow($pt)
Write-Host "Waiting 45 seconds for the Packet Tracer network to converge..."
Start-Sleep -Seconds 45

if (Test-Path $framesDir) { Remove-Item $framesDir -Recurse -Force }
New-Item -ItemType Directory -Path $framesDir | Out-Null

$job = Start-Job -ScriptBlock {
  param($dir, $log)
  Start-Sleep -Seconds 2
  Set-Location $dir
  node demo.mjs *> $log
} -ArgumentList $demoDir, $demoLog

# The region includes the top-center control indicator and the PC0 device window.
$capX = 560
$capY = 0
$capW = 800
$capH = 900
Write-Host "Recording region ${capW}x${capH} for 30 seconds..."

$fps = 8
$totalFrames = 30 * $fps
$frameInterval = 1000 / $fps
for ($i = 0; $i -lt $totalFrames; $i++) {
  $started = Get-Date
  $bmp = New-Object System.Drawing.Bitmap $capW, $capH
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($capX, $capY, 0, 0, $bmp.Size)
  $g.Dispose()
  $bmp.Save((Join-Path $framesDir ("frame_{0:D4}.png" -f $i)), [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  $elapsed = ((Get-Date) - $started).TotalMilliseconds
  if ($elapsed -lt $frameInterval) { Start-Sleep -Milliseconds ([int]($frameInterval - $elapsed)) }
}

Wait-Job $job -Timeout 40 | Out-Null
Receive-Job $job -AutoRemoveJob -Wait | Out-Null

$filter = "[0:v]scale=700:700:force_original_aspect_ratio=decrease,pad=720:700:(ow-iw)/2:(oh-ih)/2:color=0x0b0b0f[app];" +
  "[1:v][app]overlay=560:10[bg];" +
  "[bg]drawtext=fontfile=.demo-font.ttf:text='LIVE DEMO':fontcolor=0x6b7280:fontsize=16:x=48:y=48," +
  "drawtext=fontfile=.demo-font-bold.ttf:text='Computer Use MCP':fontcolor=white:fontsize=46:x=48:y=110," +
  "drawtext=fontfile=.demo-font.ttf:text='Packet Tracer automation':fontcolor=0x9aa4b2:fontsize=22:x=48:y=172," +
  "drawtext=fontfile=.demo-font.ttf:text='Neutral control indicator':fontcolor=0x9aa4b2:fontsize=22:x=48:y=204," +
  "drawtext=fontfile=.demo-font.ttf:text='Esc to cancel':fontcolor=0x9aa4b2:fontsize=18:x=48:y=236," +
  "drawbox=x=540:y=40:w=1:h=640:color=0x1f2937:t=fill," +
  "drawtext=fontfile=.demo-font-bold.ttf:text='1  open PC0':fontcolor=0xe5e7eb:fontsize=22:x=48:y=280," +
  "drawtext=fontfile=.demo-font-bold.ttf:text='2  Desktop - Command Prompt':fontcolor=0xe5e7eb:fontsize=22:x=48:y=326," +
  "drawtext=fontfile=.demo-font-bold.ttf:text='3  ipconfig':fontcolor=0xe5e7eb:fontsize=22:x=48:y=372," +
  "drawtext=fontfile=.demo-font-bold.ttf:text='4  ping gateway - 4/4':fontcolor=0xe5e7eb:fontsize=22:x=48:y=418," +
  "drawtext=fontfile=.demo-font.ttf:text='14 native MCP tools - deterministic batching':fontcolor=0x9aa4b2:fontsize=18:x=48:y=640," +
  "drawtext=fontfile=.demo-font.ttf:text='Windows 10/11 - stdio JSON-RPC - no dependencies':fontcolor=0x6b7280:fontsize=16:x=48:y=666," +
  "format=yuv420p[v]"

$ffArgs = @(
  '-y', '-hide_banner', '-loglevel', 'error',
  '-framerate', "$fps", '-i', (Join-Path $framesDir 'frame_%04d.png'),
  '-f', 'lavfi', '-i', 'color=c=0x0b0b0f:s=1280x720:r=15',
  '-filter_complex', $filter,
  '-map', '[v]', '-t', '30', '-r', '15',
  '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '24',
  '-movflags', '+faststart', $Output
)
& ffmpeg @ffArgs 2> $ffLog
if ($LASTEXITCODE -ne 0) { throw "ffmpeg failed; see $ffLog" }
if (-not (Test-Path $Output)) { throw "Recording was not created" }

Write-Host "Closing Packet Tracer..."
Push-Location $demoDir
try { node demo.mjs --close-only | Out-Null } finally { Pop-Location }

Remove-Item $framesDir -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $boldFont, $font -Force -ErrorAction SilentlyContinue
Write-Host "Recorded: $Output"
