param(
  [string]$ExePath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'bin\QoderComputerUse.exe'),
  [string]$Text = 'Computer Use active - Esc to cancel'
)

$ErrorActionPreference = 'Stop'

$Utf8Bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
$Len = $Utf8Bytes.Length
if ($Len -lt 1 -or $Len -gt 95) {
  throw "Indicator text must be between 1 and 95 UTF-8 bytes (got $Len bytes)."
}
if (-not (Test-Path $ExePath)) {
  throw "Executable not found: $ExePath"
}

Get-Process -Name 'QoderComputerUse' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 400

function Write-Float32([byte[]]$Buffer, [int]$Offset, [float]$Value) {
  $Bytes = [BitConverter]::GetBytes([single]$Value)
  [Array]::Copy($Bytes, 0, $Buffer, $Offset, 4)
}

function Write-RgbMultipliers([byte[]]$Buffer, [int]$BOffset, [int]$GOffset, [int]$ROffset, [int]$R, [int]$G, [int]$B) {
  $BMul = [BitConverter]::GetBytes([uint32]($B * 0x8081))
  $BSeq = [byte[]]@(0x44, 0x69, 0xC8, $BMul[0], $BMul[1], $BMul[2], $BMul[3], 0x41, 0xC1, 0xE9, 0x17)
  [Array]::Copy($BSeq, 0, $Buffer, $BOffset, 11)

  $GMul = [BitConverter]::GetBytes([uint32]($G * 0x8081))
  $GSeq = [byte[]]@(0x41, 0x69, 0xC8, $GMul[0], $GMul[1], $GMul[2], $GMul[3], 0xC1, 0xE9, 0x17)
  [Array]::Copy($GSeq, 0, $Buffer, $GOffset, 10)

  $RMul = [BitConverter]::GetBytes([uint32]($R * 0x8081))
  $RSeq = [byte[]]@(0x41, 0x69, 0xC8, $RMul[0], $RMul[1], $RMul[2], $RMul[3], 0xC1, 0xE9, 0x17)
  [Array]::Copy($RSeq, 0, $Buffer, $ROffset, 10)
}

[byte[]]$Data = [System.IO.File]::ReadAllBytes($ExePath)

# 1. Replace the 95-byte overlay text slot.
for ($i = 0; $i -lt 95; $i++) {
  $Data[0x1FD0E8 + $i] = if ($i -lt $Len) { $Utf8Bytes[$i] } else { 0 }
}

# 2. Patch the four overlay string pointer/length sites.
[byte[]]$Patch1 = @(0x48, 0x89, 0xC2, 0x90, 0x90, 0x90, 0x90, 0x48, 0x83, 0xC1, [byte]$Len)
[Array]::Copy($Patch1, 0, $Data, 0x1431CE, $Patch1.Length)

[byte[]]$Patch2Len = @(0x90, 0x90, 0x90, 0x90, 0x48, 0x83, 0xC6, [byte]$Len)
[Array]::Copy($Patch2Len, 0, $Data, 0x143D5F, $Patch2Len.Length)
[byte[]]$Patch2Mov = @(0x48, 0x89, 0xC2, 0x90)
[Array]::Copy($Patch2Mov, 0, $Data, 0x143D9F, $Patch2Mov.Length)

[Array]::Copy($Patch2Len, 0, $Data, 0x144142, $Patch2Len.Length)
[Array]::Copy($Patch2Mov, 0, $Data, 0x144181, $Patch2Mov.Length)

[byte[]]$Patch4 = @(0x48, 0x89, 0xCA, 0x90, 0x90, 0x90, 0x90, 0x48, 0x83, 0xC0, [byte]$Len)
[Array]::Copy($Patch4, 0, $Data, 0x146350, $Patch4.Length)

# 3. Neutral indicator theme: dark card with an amber border glow.
$GlowSites = @(
  @{ B = 0x147448; G = 0x147493; R = 0x1474D8 },
  @{ B = 0x147774; G = 0x1477B9; R = 0x1477FE },
  @{ B = 0x147B24; G = 0x147B6F; R = 0x147BB4 },
  @{ B = 0x147DD0; G = 0x147E1D; R = 0x147E5E },
  @{ B = 0x148744; G = 0x148788; R = 0x1487CC }
)
foreach ($Site in $GlowSites) {
  Write-RgbMultipliers -Buffer $Data -BOffset $Site.B -GOffset $Site.G -ROffset $Site.R -R 245 -G 158 -B 11
}
Write-Float32 -Buffer $Data -Offset 0x1FC628 -Value 125.0
Write-Float32 -Buffer $Data -Offset 0x1FC62C -Value 95.0

# Dark card surface (#121215 -> #09090B) with a subtle ring.
Write-Float32 -Buffer $Data -Offset 0x1FC68C -Value -10.0
Write-Float32 -Buffer $Data -Offset 0x1FC690 -Value 21.0
Write-Float32 -Buffer $Data -Offset 0x1FC694 -Value -9.0
Write-Float32 -Buffer $Data -Offset 0x1FC698 -Value 18.0
Write-Float32 -Buffer $Data -Offset 0x1FC69C -Value -9.0
Write-Float32 -Buffer $Data -Offset 0x1FC6A0 -Value 18.0
Write-Float32 -Buffer $Data -Offset 0x1FC6A8 -Value 8.0
Write-Float32 -Buffer $Data -Offset 0x1FC6AC -Value 64.0
Write-Float32 -Buffer $Data -Offset 0x1FC6B4 -Value 252.0
Write-Float32 -Buffer $Data -Offset 0x1FC6B8 -Value 254.0
Write-Float32 -Buffer $Data -Offset 0x1FC6BC -Value 46.0

# 4. The patch invalidates the Authenticode signature; clear its directory entry.
for ($i = 0; $i -lt 8; $i++) {
  $Data[400 + $i] = 0
}

[System.IO.File]::WriteAllBytes($ExePath, $Data)
Write-Host "Indicator text: `"$Text`" ($Len bytes) -> $ExePath"
