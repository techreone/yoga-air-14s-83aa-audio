# 将 TAS2XXX38BA 固件替换为指定版本（需管理员）
param(
    [string]$Firmware = "",
    [switch]$NoReinit
)

$ErrorActionPreference = 'Stop'
$dst = 'C:\Windows\System32\drivers\TAS2XXX38BA.bin'
$bak = 'C:\Windows\System32\drivers\TAS2XXX38BA.bin.bak-orig'

if (-not $Firmware) { $Firmware = Join-Path $PSScriptRoot '..\firmware\TAS2XXX38BA_v4.0_20221113_64536B.bin' }
if (-not (Test-Path $Firmware)) { throw "firmware not found: $Firmware" }

if (-not (Test-Path $bak)) {
    Copy-Item $dst $bak -Force
    Write-Host "backup -> $bak"
}

takeown /f $dst | Out-Null
icacls $dst /grant "*S-1-5-32-544:F" | Out-Null
Copy-Item $Firmware $dst -Force
Write-Host ("installed: {0} bytes MD5 {1}" -f (Get-Item $dst).Length, (Get-FileHash $dst -Algorithm MD5).Hash)

if (-not $NoReinit) {
    reg delete "HKLM\SYSTEM\TIUpdateInformation" /f 2>$null | Out-Null
    Disable-PnpDevice -InstanceId 'ACPI\TIAS2781\0' -Confirm:$false
    Start-Sleep -Seconds 3
    Enable-PnpDevice -InstanceId 'ACPI\TIAS2781\0' -Confirm:$false
    Start-Sleep -Seconds 4
    Write-Host ("device: " + (Get-PnpDevice -InstanceId 'ACPI\TIAS2781\0').Status)
    if (Test-Path 'HKLM:\SYSTEM\TIUpdateInformation') {
        Get-ItemProperty 'HKLM:\SYSTEM\TIUpdateInformation\fwUpdateParameter' |
            Select-Object clockSuppliedByCODEC, pathBinaryStrName, lastUpdateFwStatus, DownloadTime |
            Format-List
    }
}
