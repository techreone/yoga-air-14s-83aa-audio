# 还原为原始（零售版 v8.0）固件（需管理员）
$ErrorActionPreference = 'Stop'
$dst = 'C:\Windows\System32\drivers\TAS2XXX38BA.bin'
$bak = 'C:\Windows\System32\drivers\TAS2XXX38BA.bin.bak-orig'

if (-not (Test-Path $bak)) { throw "backup not found: $bak" }

takeown /f $dst | Out-Null
icacls $dst /grant "*S-1-5-32-544:F" | Out-Null
Copy-Item $bak $dst -Force
Write-Host ("restored: {0} bytes MD5 {1}" -f (Get-Item $dst).Length, (Get-FileHash $dst -Algorithm MD5).Hash)

reg delete "HKLM\SYSTEM\TIUpdateInformation" /f 2>$null | Out-Null
Disable-PnpDevice -InstanceId 'ACPI\TIAS2781\0' -Confirm:$false
Start-Sleep -Seconds 3
Enable-PnpDevice -InstanceId 'ACPI\TIAS2781\0' -Confirm:$false
Start-Sleep -Seconds 4
Write-Host ("device: " + (Get-PnpDevice -InstanceId 'ACPI\TIAS2781\0').Status)
