# Collect every audio-related driver file from this machine into the repo.
# Large payload files (> 8 MB) are skipped on purpose: they are already inside
# the official Lenovo installers, whose URLs and hashes are recorded in MANIFEST.md.
# Elevoc ships ~300 MB of voice models per folder; only its INF/CAT are kept.
param(
    [string]$OutRoot = (Join-Path $PSScriptRoot '..\archive'),
    [int]$MaxFileBytes = 8000000
)

$ErrorActionPreference = 'Stop'
$ds = 'C:\Windows\System32\DriverStore\FileRepository'
$OutRoot = (Resolve-Path (New-Item -ItemType Directory -Force -Path $OutRoot)).Path

$folders = Get-ChildItem $ds -Directory | Where-Object {
    $_.Name -match '^(tas2xxx|hdxacplv|hdx_lenovoext|dax3_|realtekapo|realtekservice|elevocapo|amdacpafd|atihdwt6)'
}

$skipped = New-Object System.Collections.Generic.List[object]
$copied = 0

foreach ($f in $folders) {
    $leanOnly = $f.Name -like 'elevocapo*'
    foreach ($file in Get-ChildItem $f.FullName -Recurse -File) {
        $rel = $file.FullName.Substring($f.FullName.Length + 1)
        if ($leanOnly -and $file.Extension -notin '.inf', '.cat') {
            $skipped.Add([pscustomobject]@{ Folder = $f.Name; File = $rel; Bytes = $file.Length; Reason = 'elevoc payload' })
            continue
        }
        if ($file.Length -gt $MaxFileBytes) {
            $skipped.Add([pscustomobject]@{ Folder = $f.Name; File = $rel; Bytes = $file.Length; Reason = 'too large' })
            continue
        }
        $dest = Join-Path (Join-Path $OutRoot 'driverstore') (Join-Path $f.Name $rel)
        New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
        Copy-Item $file.FullName $dest -Force
        $copied++
    }
}

# runtime firmware actually loaded by the amp (lives outside the driver store)
$runtime = 'C:\Windows\System32\drivers'
New-Item -ItemType Directory -Force -Path (Join-Path $OutRoot 'runtime') | Out-Null
foreach ($n in 'TAS2XXX38BA.bin', 'TAS2XXX38BB.bin', 'TAS2XXXFirmware.bin', 'TAS2xxx.sys') {
    $src = Join-Path $runtime $n
    if (Test-Path $src) {
        Copy-Item $src (Join-Path (Join-Path $OutRoot 'runtime') $n) -Force
        $copied++
    }
}

$skipped | Sort-Object Bytes -Descending | Export-Csv (Join-Path $OutRoot 'skipped-files.csv') -NoTypeInformation -Encoding UTF8

Write-Host "copied $copied files into $OutRoot"
Write-Host "skipped $($skipped.Count) files"
$skipped | Sort-Object Bytes -Descending | Select-Object -First 8 | Format-Table -AutoSize
