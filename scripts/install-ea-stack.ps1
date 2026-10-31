# Install the 2023-02 "EA-era" audio stack on Yoga Air 14s 83AA.
# Must run elevated (one UAC click). Reversible: run revert-ea-stack.ps1 or reinstall
# the official 2025 package (kxks047f5xecgff0.exe).
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File install-ea-stack.ps1
#   powershell -ExecutionPolicy Bypass -File install-ea-stack.ps1 -SkipTi -SkipFirmware
param(
    [switch]$SkipTi,
    [switch]$SkipFirmware,
    [switch]$SkipRealtek
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$fwV4 = Join-Path $root 'firmware\TAS2XXX38BA_v4.0_20221113_64536B.bin'
$tiDir = Join-Path $root 'drivers\ti-1.3.29.0'
$fwDst = 'C:\Windows\System32\drivers\TAS2XXX38BA.bin'
$fwBak = 'C:\Windows\System32\drivers\TAS2XXX38BA.bin.bak-orig'

function Assert-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Run this script from an elevated PowerShell window.'
    }
}

function Get-OemInf([string]$pattern) {
    $out = pnputil /enum-drivers
    $res = @()
    $cur = @{}
    foreach ($line in $out) {
        if ($line -match 'oem\d+\.inf') { $cur['Published'] = $Matches[0] }
        if ($line -match '(?i)Original Name|orginal|inf') { }
        if ($cur.Count -gt 0 -and $line -match '(.+\.inf)\s*$') {
            $name = ($Matches[1] -replace '.*[\\/]', '').Trim()
            if ($name -match $pattern -and $cur['Published']) {
                $res += [pscustomobject]@{ Published = $cur['Published']; Inf = $name }
                $cur = @{}
            }
        }
    }
    $res | Select-Object -Unique Published, Inf
}

function Show-AudioDrivers {
    foreach ($id in 'ACPI\TIAS2781\0', 'HDAUDIO\FUNC_01&VEN_10EC&DEV_0287&SUBSYS_17AA38BA&REV_1000') {
        $dev = Get-PnpDevice -InstanceId $id -ErrorAction SilentlyContinue
        if (-not $dev) { continue }
        $ver = (Get-PnpDeviceProperty -InstanceId $id -KeyName 'DEVPKEY_Device_DriverVersion').Data
        $inf = (Get-PnpDeviceProperty -InstanceId $id -KeyName 'DEVPKEY_Device_DriverInfPath').Data
        [pscustomobject]@{ Device = $dev.FriendlyName; Version = $ver; Inf = $inf }
    }
}

Assert-Admin
Write-Host '== before =='
Show-AudioDrivers | Format-Table -AutoSize

if (-not $SkipRealtek) {
    $rtk = 'C:\Temp\opencode\kxks017f5xecgff0.exe'
    if (Test-Path $rtk) {
        Write-Host "== installing Realtek 6.0.9456.1 from $rtk =="
        $p = Start-Process -FilePath $rtk -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART' -Wait -PassThru
        Write-Host ("installer exit code: " + $p.ExitCode)
    } else {
        Write-Warning "Realtek 6.0.9456.1 package not found, keeping the current codec driver."
    }
    $rtkId = 'HDAUDIO\FUNC_01&VEN_10EC&DEV_0287&SUBSYS_17AA38BA&REV_1000'
    $rtkVer = (Get-PnpDeviceProperty -InstanceId $rtkId -KeyName 'DEVPKEY_Device_DriverVersion' -ErrorAction SilentlyContinue).Data
    if ($rtkVer -and $rtkVer -ne '6.0.9456.1') {
        Write-Warning "Realtek stayed at $rtkVer: the installer only adds the older package to the store, Windows keeps the newer one bound."
        Write-Warning "That is fine - the codec driver is not the lever, the amp firmware is. Nothing to fix here."
    }
}

if (-not $SkipTi) {
    Write-Host "== installing TI Smart Amp 1.3.29.0 =="
    Get-CimInstance Win32_PnPSignedDriver |
        Where-Object { $_.DeviceName -match 'TI Smart Amplifier' } |
        ForEach-Object {
            Write-Host ("removing current package " + $_.InfName)
            pnputil /delete-driver $_.InfName /uninstall /force
        }
    pnputil /add-driver (Join-Path $tiDir 'TAS2xxx.inf') /install /force
    pnputil /scan-devices
    Start-Sleep -Seconds 3
}

if (-not $SkipFirmware) {
    Write-Host '== writing firmware v4.0 (64,536 B) =='
    if (-not (Test-Path $fwBak)) { Copy-Item $fwDst $fwBak -Force; Write-Host "backup -> $fwBak" }
    takeown /f $fwDst | Out-Null
    icacls $fwDst /grant '*S-1-5-32-544:F' | Out-Null
    Copy-Item $fwV4 $fwDst -Force
    Write-Host ("installed: {0} bytes MD5 {1}" -f (Get-Item $fwDst).Length, (Get-FileHash $fwDst -Algorithm MD5).Hash)

    reg delete 'HKLM\SYSTEM\TIUpdateInformation' /f 2>$null | Out-Null
    Disable-PnpDevice -InstanceId 'ACPI\TIAS2781\0' -Confirm:$false
    Start-Sleep -Seconds 3
    Enable-PnpDevice -InstanceId 'ACPI\TIAS2781\0' -Confirm:$false
    Start-Sleep -Seconds 4
    Write-Host ('device: ' + (Get-PnpDevice -InstanceId 'ACPI\TIAS2781\0').Status)
    if (Test-Path 'HKLM:\SYSTEM\TIUpdateInformation') {
        Get-ItemProperty 'HKLM:\SYSTEM\TIUpdateInformation\fwUpdateParameter' |
            Select-Object clockSuppliedByCODEC, pathBinaryStrName, lastUpdateFwStatus, DownloadTime | Format-List
    }
}

Write-Host '== after =='
Show-AudioDrivers | Format-Table -AutoSize
Write-Host 'Done. A reboot is recommended.'
