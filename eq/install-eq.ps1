# Install Equalizer APO and apply the compensation curve.
# Needs one UAC click. After it finishes, open EqualizerAPO's Configurator
# and tick "Speakers (Realtek(R) Audio)" so the APO is bound to the laptop
# speakers only (not to the 3.5 mm / external speaker endpoint).
param(
    [string]$Installer = 'C:\Temp\opencode\EqualizerAPO-x64-1.4.2.exe'
)

$ErrorActionPreference = 'Stop'

$id = [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this script from an elevated PowerShell window.'
}

if (-not (Test-Path $Installer)) { throw "installer not found: $Installer" }

$cfgDir = 'C:\Program Files\EqualizerAPO\config'
$cfgSrc = Join-Path (Split-Path -Parent $PSScriptRoot) 'eq\equalizer-apo-config.txt'

if (-not (Test-Path $cfgDir)) {
    Write-Host 'installing Equalizer APO ...'
    $p = Start-Process -FilePath $Installer -ArgumentList '/S' -Wait -PassThru
    Write-Host ('installer exit code: ' + $p.ExitCode)
    Start-Sleep -Seconds 2
}

if (-not (Test-Path $cfgDir)) { throw 'Equalizer APO config folder not found after install.' }

Copy-Item $cfgSrc (Join-Path $cfgDir 'config.txt') -Force
Write-Host ('config written to ' + (Join-Path $cfgDir 'config.txt'))
Write-Host 'Now open "Configurator" from the Start menu and tick: 扬声器 (Realtek(R) Audio)'
Write-Host 'Then restart the audio service:  Restart-Service audiosrv -Force'
