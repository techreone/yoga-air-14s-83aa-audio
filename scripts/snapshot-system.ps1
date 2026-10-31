# Snapshot the machine state that made the archived drivers work.
param([string]$OutDir = (Join-Path $PSScriptRoot '..\archive\system'))

$ErrorActionPreference = 'Continue'
$OutDir = (Resolve-Path (New-Item -ItemType Directory -Force -Path $OutDir)).Path

$cs = Get-CimInstance Win32_ComputerSystem
$bios = Get-CimInstance Win32_BIOS
$os = Get-CimInstance Win32_OperatingSystem
@(
    "Manufacturer : $($cs.Manufacturer)"
    "Model        : $($cs.Model)"
    "SystemSKU    : $($cs.SystemSKUNumber)"
    "BIOS         : $($bios.SMBIOSBIOSVersion) ($($bios.ReleaseDate))"
    "OS           : $($os.Caption) $($os.Version) build $($os.BuildNumber)"
    "Captured     : $(Get-Date -Format s)"
) | Set-Content (Join-Path $OutDir 'machine.txt') -Encoding UTF8

$ids = @(
    'ACPI\TIAS2781\0'
    'HDAUDIO\FUNC_01&VEN_10EC&DEV_0287&SUBSYS_17AA38BA&REV_1000'
    'ACPI\AMDI0010\0'
)
$rows = foreach ($id in $ids) {
    $dev = Get-PnpDevice -InstanceId $id -ErrorAction SilentlyContinue
    if (-not $dev) { continue }
    [pscustomobject]@{
        InstanceId = $id
        Name       = $dev.FriendlyName
        Status     = $dev.Status
        Class      = $dev.Class
        DriverVer  = (Get-PnpDeviceProperty -InstanceId $id -KeyName 'DEVPKEY_Device_DriverVersion').Data
        DriverInf  = (Get-PnpDeviceProperty -InstanceId $id -KeyName 'DEVPKEY_Device_DriverInfPath').Data
        DriverDate = (Get-PnpDeviceProperty -InstanceId $id -KeyName 'DEVPKEY_Device_DriverDate').Data
        Provider   = (Get-PnpDeviceProperty -InstanceId $id -KeyName 'DEVPKEY_Device_DriverProvider').Data
    }
}
$rows | Format-List | Out-File (Join-Path $OutDir 'audio-devices.txt') -Encoding UTF8

pnputil /enum-drivers | Out-File (Join-Path $OutDir 'pnputil-enum-drivers.txt') -Encoding UTF8

$reg = @()
foreach ($k in 'HKLM:\SYSTEM\TIUpdateInformation', 'HKLM:\SYSTEM\TISmartAmpCalibration') {
    if (Test-Path $k) {
        $reg += "== $k =="
        $item = Get-Item $k
        foreach ($p in $item.Property) { $reg += ("{0} = {1}" -f $p, (Get-ItemProperty $k).$p) }
        foreach ($sub in Get-ChildItem $k -ErrorAction SilentlyContinue) {
            $reg += "== $($sub.Name) =="
            foreach ($p in $sub.Property) { $reg += ("{0} = {1}" -f $p, (Get-ItemProperty $sub.PSPath).$p) }
        }
    } else {
        $reg += "== $k (MISSING) =="
    }
}
$reg | Out-File (Join-Path $OutDir 'registry-ti.txt') -Encoding UTF8

$ep = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render' |
    ForEach-Object {
        $props = Get-ItemProperty (Join-Path $_.PSPath 'Properties') -ErrorAction SilentlyContinue
        [pscustomobject]@{
            Guid  = $_.PSChildName
            Name  = $props.'{b3f8fa53-0004-438e-9003-51a46e139bfc},6'
            State = (Get-ItemProperty $_.PSPath).DeviceState
            Form  = $props.'{1da5d803-d492-4edd-8c23-e0c0ffee7f0e},0'
        }
    }
$ep | Format-Table -AutoSize | Out-File (Join-Path $OutDir 'audio-endpoints.txt') -Encoding UTF8

$eq = 'C:\Program Files\EqualizerAPO\config\config.txt'
if (Test-Path $eq) {
    Copy-Item $eq (Join-Path $OutDir 'equalizer-apo-config.txt') -Force
}

Write-Host "snapshot written to $OutDir"
