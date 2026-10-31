# cycles the Equalizer APO preset on the laptop speakers endpoint
# usage: powershell -ExecutionPolicy Bypass -File switch-preset.ps1 [-Name A|D]
param([string]$Name)

$ErrorActionPreference = 'Stop'
$configPath = 'C:\Program Files\EqualizerAPO\config\config.txt'
$presetDir = Join-Path $PSScriptRoot 'presets'

$presets = Get-ChildItem $presetDir -Filter '*.txt' | Sort-Object Name
if (-not $presets) { throw "no presets in $presetDir" }

$current = if (Test-Path $configPath) { (Get-Content $configPath -Raw) } else { '' }

if ($Name) {
    $pick = $presets | Where-Object { $_.BaseName -like "$Name*" } | Select-Object -First 1
    if (-not $pick) { throw "no preset matching '$Name'" }
} else {
    $idx = 0
    for ($i = 0; $i -lt $presets.Count; $i++) {
        if ($current.Trim() -eq (Get-Content $presets[$i].FullName -Raw).Trim()) { $idx = $i; break }
    }
    $pick = $presets[($idx + 1) % $presets.Count]
}

# keep the -6 dB headroom: the raw preset files carry their own Preamp line,
# so take the file as is
[System.IO.File]::WriteAllText($configPath, (Get-Content $pick.FullName -Raw), [System.Text.Encoding]::ASCII)
Write-Host "active preset: $($pick.BaseName)"
Get-Content $configPath
