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

Copy-Item 'C:\Windows\Fonts\segoeuib.ttf' $boldFont -Force
Copy-Item 'C:\Windows\Fonts\segoeui.ttf' $font -Force

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class DemoWin {
  public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lp);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int hh, bool repaint);
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
}
"@

function Find-Window([string]$Title) {
  $script:found = [IntPtr]::Zero
  [DemoWin]::EnumWindows({
    param($h, $l)
    if ([DemoWin]::IsWindowVisible($h)) {
      $sb = New-Object System.Text.StringBuilder 512
      [void][DemoWin]::GetWindowText($h, $sb, 512)
      if ($sb.ToString() -eq $Title) {
        $script:found = $h
        return $false
      }
    }
    return $true
  }, [IntPtr]::Zero) | Out-Null
  return $script:found
}

Write-Host "Opening Calculator..."
Start-Process calc.exe | Out-Null
Start-Sleep -Seconds 2

$calc = Find-Window 'Calculator'
if ($calc -eq [IntPtr]::Zero) { throw 'Calculator window not found' }
$screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$w = 640
$h = 720
$x = [int](($screen.Width - $w) / 2)
$y = 0
[void][DemoWin]::MoveWindow($calc, $x, $y, $w, $h, $true)
[void][DemoWin]::SetForegroundWindow($calc)
Start-Sleep -Milliseconds 600

$client = New-Object DemoWin+RECT
[void][DemoWin]::GetClientRect($calc, [ref]$client)
$origin = New-Object DemoWin+POINT
[void][DemoWin]::ClientToScreen($calc, [ref]$origin)
$x = $origin.X
$y = $origin.Y
$w = $client.Right - $client.Left
$h = $client.Bottom - $client.Top
Write-Host "Capturing client area ${w}x${h} at ($x,$y)..."

if (Test-Path $framesDir) { Remove-Item $framesDir -Recurse -Force }
New-Item -ItemType Directory -Path $framesDir | Out-Null

$job = Start-Job -ScriptBlock {
  param($dir, $log)
  Start-Sleep -Seconds 2
  Set-Location $dir
  node demo.mjs *> $log
} -ArgumentList $demoDir, $demoLog

Write-Host "Recording for 20 seconds..."
$fps = 10
$totalFrames = 20 * $fps
$frameInterval = 1000 / $fps
for ($i = 0; $i -lt $totalFrames; $i++) {
  $started = Get-Date
  $bmp = New-Object System.Drawing.Bitmap $w, $h
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($x, $y, 0, 0, $bmp.Size)
  $g.Dispose()
  $path = Join-Path $framesDir ("frame_{0:D4}.png" -f $i)
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  $elapsed = ((Get-Date) - $started).TotalMilliseconds
  if ($elapsed -lt $frameInterval) { Start-Sleep -Milliseconds ([int]($frameInterval - $elapsed)) }
}

Wait-Job $job -Timeout 30 | Out-Null
Receive-Job $job -AutoRemoveJob -Wait | Out-Null

$filter = "[0:v]scale=700:700:force_original_aspect_ratio=decrease,pad=720:700:(ow-iw)/2:(oh-ih)/2:color=0x0b0b0f[calc];" +
  "[1:v][calc]overlay=560:10[bg];" +
  "[bg]drawtext=fontfile=.demo-font.ttf:text='LIVE DEMO':fontcolor=0x6b7280:fontsize=16:x=48:y=48," +
  "drawtext=fontfile=.demo-font-bold.ttf:text='Computer Use MCP':fontcolor=white:fontsize=46:x=48:y=110," +
  "drawtext=fontfile=.demo-font.ttf:text='Native Windows automation':fontcolor=0x9aa4b2:fontsize=22:x=48:y=172," +
  "drawtext=fontfile=.demo-font.ttf:text='Neutral control indicator':fontcolor=0x9aa4b2:fontsize=22:x=48:y=204," +
  "drawtext=fontfile=.demo-font.ttf:text='Esc to cancel':fontcolor=0x9aa4b2:fontsize=18:x=48:y=236," +
  "drawbox=x=540:y=40:w=1:h=640:color=0x1f2937:t=fill," +
  "drawtext=fontfile=.demo-font-bold.ttf:text='1  list_windows':fontcolor=0xe5e7eb:fontsize=22:x=48:y=280," +
  "drawtext=fontfile=.demo-font-bold.ttf:text='2  get_window_state':fontcolor=0xe5e7eb:fontsize=22:x=48:y=326," +
  "drawtext=fontfile=.demo-font-bold.ttf:text='3  run_steps  7 x 8 = 56':fontcolor=0xe5e7eb:fontsize=22:x=48:y=372," +
  "drawtext=fontfile=.demo-font-bold.ttf:text='4  final_state verified':fontcolor=0xe5e7eb:fontsize=22:x=48:y=418," +
  "drawtext=fontfile=.demo-font.ttf:text='14 native MCP tools - deterministic batching':fontcolor=0x9aa4b2:fontsize=18:x=48:y=640," +
  "drawtext=fontfile=.demo-font.ttf:text='Windows 10/11 - stdio JSON-RPC - no dependencies':fontcolor=0x6b7280:fontsize=16:x=48:y=666," +
  "format=yuv420p[v]"

$ffArgs = @(
  '-y', '-hide_banner', '-loglevel', 'error',
  '-framerate', "$fps", '-i', (Join-Path $framesDir 'frame_%04d.png'),
  '-f', 'lavfi', '-i', 'color=c=0x0b0b0f:s=1280x720:r=15',
  '-filter_complex', $filter,
  '-map', '[v]', '-t', '20', '-r', '15',
  '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '24',
  '-movflags', '+faststart', $Output
)
& ffmpeg @ffArgs 2> $ffLog
if ($LASTEXITCODE -ne 0) { throw "ffmpeg failed; see $ffLog" }
if (-not (Test-Path $Output)) { throw "Recording was not created" }

Write-Host "Closing demo Calculator..."
Push-Location $demoDir
try { node demo.mjs --close-only | Out-Null } finally { Pop-Location }

Remove-Item $framesDir -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $boldFont, $font -Force -ErrorAction SilentlyContinue
Write-Host "Recorded: $Output"
