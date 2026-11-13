#Requires -RunAsAdministrator
<#
  Yoga Air 14s 2023 (83AA) audio repair after a Windows Update.

  Two things Windows Update breaks:
    1) "Texas Instruments - System - 1.10.2.1" pushes the retail amp firmware
       (FCAA167B, 64,732 B) back to C:\Windows\System32\drivers\TAS2XXX38BA.bin
       -> tiny + distorted sound. This script restores the v4.0 firmware.
    2) the Realtek speaker endpoint may be re-created with a new GUID, so
       Equalizer APO loses its binding -> EQ preset stops working. This script
       re-binds APO to whatever the current speaker endpoint is.

  Usage:
    powershell -ExecutionPolicy Bypass -File fix-after-wu.ps1
    powershell -ExecutionPolicy Bypass -File fix-after-wu.ps1 -InstallGuard
      -> also registers a SYSTEM startup task that re-applies the fix silently
         after every boot, so a future update cannot break the sound again.
#>
[CmdletBinding()]
param([switch]$InstallGuard)

$ErrorActionPreference = 'Stop'
$dst  = 'C:\Windows\System32\drivers\TAS2XXX38BA.bin'
$src  = Join-Path $PSScriptRoot '..\firmware\TAS2XXX38BA_v4.0_20221113_64536B.bin'
$want = 'AE9E2EA9B5E41E8787FF3BE992143ACF'
$fxKey   = '{d04e05a6-594b-4fb6-a80d-01af5eed7d1d}'
$eapoSfx = '{EACD2258-FCAC-4FF4-B36D-419E924A6D79}'
$eapoEfx = '{EC1CC9CE-FAED-4822-828A-82A81A6F018F}'
$renderRoot = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render'
$speakerLabel = [string]([char]0x626C + [char]0x58F0 + [char]0x5668)   # 扬声器

function Get-Md5([string]$Path) { (Get-FileHash $Path -Algorithm MD5).Hash }

# --- privileges needed to touch MMDevices ACLs --------------------------------
if (-not ('Priv' -as [type])) {
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Priv {
  [StructLayout(LayoutKind.Sequential)] public struct LUID { public uint Low; public int High; }
  [StructLayout(LayoutKind.Sequential)] public struct TOKEN_PRIVILEGES { public uint Count; public LUID Luid; public uint Attr; }
  [DllImport("advapi32.dll", SetLastError=true)] public static extern bool OpenProcessToken(IntPtr h, uint acc, out IntPtr tok);
  [DllImport("advapi32.dll", SetLastError=true, CharSet=CharSet.Unicode)] public static extern bool LookupPrivilegeValue(string host, string name, out LUID luid);
  [DllImport("advapi32.dll", SetLastError=true)] public static extern bool AdjustTokenPrivileges(IntPtr tok, bool dis, ref TOKEN_PRIVILEGES neu, uint len, IntPtr prev, IntPtr ret);
  [DllImport("kernel32.dll")] public static extern IntPtr GetCurrentProcess();
  public static void Enable(string name) {
    IntPtr tok; OpenProcessToken(GetCurrentProcess(), 0x28, out tok);
    LUID luid; LookupPrivilegeValue(null, name, out luid);
    TOKEN_PRIVILEGES tp; tp.Count = 1; tp.Luid = luid; tp.Attr = 2;
    AdjustTokenPrivileges(tok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
  }
}
"@
}
[Priv]::Enable('SeTakeOwnershipPrivilege')
[Priv]::Enable('SeRestorePrivilege')

# --- 1. firmware --------------------------------------------------------------
Write-Host '== [1/2] amp firmware =='
if (-not (Test-Path $src)) { throw "missing $src" }
if ((Get-Md5 $src) -ne $want) { throw "bad source firmware: $src" }
$cur = if (Test-Path $dst) { Get-Md5 $dst } else { '' }
Write-Host "current: $cur"
if ($cur -ne $want) {
    takeown /f $dst | Out-Null
    icacls $dst /grant '*S-1-5-32-544:F' | Out-Null
    Copy-Item $src $dst -Force
    $now = Get-Md5 $dst
    if ($now -ne $want) { throw "copy failed, md5=$now" }
    Write-Host 'firmware replaced with v4.0'
} else {
    Write-Host 'firmware already v4.0'
}

# --- 2. Equalizer APO binding ------------------------------------------------
Write-Host '== [2/2] Equalizer APO binding =='
$target = $null
foreach ($g in Get-ChildItem $renderRoot) {
    $props = Get-ItemProperty (Join-Path $g.PSPath 'Properties') -ErrorAction SilentlyContinue
    $name  = $props.'{a45c254e-df1c-4efd-8020-67d146a850e0},2'
    $devid = $props.'{b3f8fa53-0004-438e-9003-51a46e139bfc},6'
    $state = (Get-ItemProperty $g.PSPath -ErrorAction SilentlyContinue).DeviceState
    if ($name -eq $speakerLabel -and $devid -match 'Realtek' -and $state -eq 1) { $target = $g.PSChildName }
}
if (-not $target) { throw 'active Realtek speaker endpoint not found' }
Write-Host "endpoint: $target"

$sub = "SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render\$target\FxProperties"
$already = (Get-ItemProperty "HKLM:\$sub" -ErrorAction SilentlyContinue)."$fxKey,5"
if ($already -ne $eapoSfx) {
    $admins = New-Object System.Security.Principal.NTAccount('BUILTIN\Administrators')
    $k = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($sub, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, [System.Security.AccessControl.RegistryRights]::TakeOwnership)
    $acl = $k.GetAccessControl([System.Security.AccessControl.AccessControlSections]::Owner)
    $acl.SetOwner($admins)
    $k.SetAccessControl($acl)
    $k.Close()

    $k = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($sub, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, [System.Security.AccessControl.RegistryRights]::ChangePermissions)
    $acl = $k.GetAccessControl()
    $acl.SetAccessRule((New-Object System.Security.AccessControl.RegistryAccessRule($admins,'FullControl','ContainerInherit,ObjectInherit','None','Allow')))
    $k.SetAccessControl($acl)
    $k.Close()

    $k = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($sub, $true)
    $k.SetValue("$fxKey,5", $eapoSfx, [Microsoft.Win32.RegistryValueKind]::String)
    $k.SetValue("$fxKey,7", $eapoEfx, [Microsoft.Win32.RegistryValueKind]::String)
    $k.Close()

    $k = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($sub, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, [System.Security.AccessControl.RegistryRights]::TakeOwnership)
    $acl = $k.GetAccessControl([System.Security.AccessControl.AccessControlSections]::Owner)
    $acl.SetOwner((New-Object System.Security.Principal.NTAccount('NT AUTHORITY\SYSTEM')))
    $k.SetAccessControl($acl)
    $k.Close()
    Write-Host 'Equalizer APO re-bound'
} else {
    Write-Host 'Equalizer APO already bound'
}

Restart-Service Audiosrv -Force
Start-Sleep -Seconds 2
Disable-PnpDevice -InstanceId 'ACPI\TIAS2781\0' -Confirm:$false
Start-Sleep -Seconds 2
Enable-PnpDevice -InstanceId 'ACPI\TIAS2781\0' -Confirm:$false
Start-Sleep -Seconds 3

Write-Host '== verify =='
Write-Host ('firmware  : ' + (Get-Md5 $dst))
$fw = Get-ItemProperty 'HKLM:\SYSTEM\TIUpdateInformation\fwUpdateParameter' -ErrorAction SilentlyContinue
Write-Host ('fw status : ' + $fw.lastUpdateFwStatus + ' (DownloadTime ' + $fw.DownloadTime + ')')
Write-Host ('apo sfx   : ' + (Get-ItemProperty "HKLM:\$sub" -ErrorAction SilentlyContinue)."$fxKey,5")
Write-Host ('TI driver : ' + (Get-PnpDeviceProperty -InstanceId 'ACPI\TIAS2781\0' -KeyName 'DEVPKEY_Device_DriverVersion').Data)

# --- optional: boot-time guard ------------------------------------------------
if ($InstallGuard) {
    Write-Host '== installing guard task =='
    $dir = 'C:\ProgramData\YogaAudio'
    New-Item -ItemType Directory -Force $dir | Out-Null
    Copy-Item $src (Join-Path $dir 'TAS2XXX38BA_v4.0.bin') -Force
    Copy-Item $PSCommandPath (Join-Path $dir 'fix.ps1') -Force
    # rewrite the $src line so the copied script finds the firmware next to itself
    $guard = Get-Content (Join-Path $dir 'fix.ps1') -Raw
    $guard = $guard -replace [regex]::Escape("Join-Path `$PSScriptRoot '..\firmware\TAS2XXX38BA_v4.0_20221113_64536B.bin'"), "(Join-Path `$PSScriptRoot 'TAS2XXX38BA_v4.0.bin')"
    Set-Content (Join-Path $dir 'fix.ps1') -Value $guard -Encoding UTF8

    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\ProgramData\YogaAudio\fix.ps1"'
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
    Register-ScheduledTask -TaskName 'YogaAudioGuard' -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
    Write-Host 'task "YogaAudioGuard" registered (runs at startup as SYSTEM)'
}

Write-Host 'Done.'
