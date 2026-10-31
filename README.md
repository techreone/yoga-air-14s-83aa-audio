# Yoga Air 14s 2023 (83AA, EA 样机) 音频修复记录

联想 **Yoga Air 14s 2023（83AA）工程样机（EA 版）** 的 6 扬声器（2 高音 + 4 低音 Smart AMP）声音极小、失真问题的排查存档。

## 机器信息

| 项 | 值 |
| --- | --- |
| Model | `83AA` |
| SystemSKU | `LENOVO_MT_83AA_BU_idea_FM_YogaAir 14s APU8` |
| 全球孪生型号 | Yoga Slim 7 14APU8 (Type 83AA) |
| 声卡 | Realtek ALC287 `HDAUDIO\FUNC_01&VEN_10EC&DEV_0287&SUBSYS_17AA38BA&REV_1000` |
| 智能功放 | TI TAS2781 `ACPI\TIAS2781` / `ACPI\VEN_TIAS&DEV_2781&SUBSYS_17AA38BA` |
| 扬声器 | 6 个：2 高音 + 4 低音（quad smart amp） |

## 关键结论

声音极小 + 失真的根因不在 Realtek 驱动版本，而在 **TI 功放固件（TAS2XXX38BA.bin）的调音版本**。

- 零售版固件 `TAS2XXX38BA.bin`（64,732 B，内部标识 `Zs780-14AIR-quad-pm2-YC-v8.0-SS4-20230313`）在这台 EA 样机上表现为**音量极小、严重失真**。
- 2022-11 开发阶段固件 `TAS2XXX38BA.bin`（64,536 B，内部标识 `S780-14_Quad-PM2_YC_v4.0_20221113`）在同一台机器上**音量恢复正常**，但仍残留轻微失真。

## 固件文件

| 文件 | 大小 | MD5 | 内部标识 | 来源 |
| --- | --- | --- | --- | --- |
| `firmware/TAS2XXX38BA_v4.0_20221113_64536B.bin` | 64,536 | `AE9E2EA9B5E41E8787FF3BE992143ACF` | `S780-14_Quad-PM2_YC_v4.0_20221113` | 联想音频包 `MMY5017FZDE18AF0.exe`（6.0.9445.1，2023-02-22）内 `6TISmartAMP_1.3.29.0_W\Firmwares\` |
| `firmware/TAS2XXX38BA_v8.0_20230313_64732B.bin` | 64,732 | `9AC11639F1B66EBE6CBBE4446B9E630C` | `Zs780-14AIR-quad-pm2-YC-v8.0-SS4-20230313` | 官方 Realtek 音频包 6.0.9456.1 / 6.0.9553.1（kxks017/kxks027/kxks037/kxks047） |
| `firmware/TAS2XXX38BB_v10.1_20230322_64504B.bin` | 64,504 | `9A6089A79EF6038691733A18C94C1005` | `S780-14AIR-AAC-pm1-quad-v10.1-20230322-SS13-alpha6` | 零售机 SSID 17AA38BB 的固件（参考用，未在本机测试） |

## 工作原理

TI 功放驱动 `TAS2xxx.sys` 在设备初始化时按子系统 ID 拼出文件名 `TAS2XXX%04x.bin`（本机 = `TAS2XXX38BA.bin`），从以下路径读取并下发给 TAS2781：

```
\SystemRoot\System32\drivers\TAS2XXX38BA.bin
```

即 `C:\Windows\System32\drivers\TAS2XXX38BA.bin`。

驱动每次初始化（启动、设备禁用/启用）都会重新下发固件，并把状态写入
`HKLM\SYSTEM\TIUpdateInformation\fwUpdateParameter`：

```
clockSuppliedByCODEC = Yes
pathBinaryStrName    = \SystemRoot\System32\drivers\TAS2XXX38ba.bin
lastUpdateFwStatus   = Status 0x0
DownloadTime         = <每次下发都会更新>
```

## 替换方法（需管理员）

```powershell
# 1. 备份
Copy-Item C:\Windows\System32\drivers\TAS2XXX38BA.bin C:\Windows\System32\drivers\TAS2XXX38BA.bin.bak-orig

# 2. 取得所有权并替换（该文件属主是 TrustedInstaller，直接复制会静默失败）
takeown /f C:\Windows\System32\drivers\TAS2XXX38BA.bin
icacls C:\Windows\System32\drivers\TAS2XXX38BA.bin /grant "*S-1-5-32-544:F"
Copy-Item .\firmware\TAS2XXX38BA_v4.0_20221113_64536B.bin C:\Windows\System32\drivers\TAS2XXX38BA.bin -Force

# 3. 让功放重新初始化（不重启）
Disable-PnpDevice -InstanceId 'ACPI\TIAS2781\0' -Confirm:$false
Enable-PnpDevice  -InstanceId 'ACPI\TIAS2781\0' -Confirm:$false
```

脚本见 `scripts/apply-firmware.ps1` 与 `scripts/revert-firmware.ps1`。

## 已排除的假设

- **重装官方驱动**：本机原装 6.0.9553.1 与联想 2025-09-02 官方包（`kxks047f5xecgff0.exe`）逐字节相同（`RTAIODAT.DAT` 56,199,150 B / MD5 `BA61F9F2806A2070886ECF8E8B560EB0`），重装是空操作。
- **降级 Realtek/TI 驱动**：6.0.9456.1 + TI 1.9.8.4 与 6.0.9553.1 + TI 1.10.2.1 表现一致，均极小 + 失真。
- **APO/音效链**：关闭空间音效与音频增强后无任何变化，排除 Dolby DAX3 / Realtek / Elevoc 处理链。
- **功放固件未下发**：`lastUpdateFwStatus = Status 0x0`，每次初始化都重新下发。
- **硬件损坏**：替换为 v4.0 固件后音量立即恢复正常，证明功放与扬声器本体完好。

## 未解决

- v4.0 固件下仍有轻微失真，怀疑存在更合适的中间版本（v5/v6/v7）或 EA 专用调音，仍在寻找。

## 这个仓库怎么用

1. 先看 `MANIFEST.md`：里面有官方安装包的直链、SHA256、每代固件的区别，以及恢复步骤。
2. 只想修好声音：按 `MANIFEST.md` 的「恢复步骤」走一遍，核心就三步——装官方包、把
   `firmware/TAS2XXX38BA_v4.0_20221113_64536B.bin` 放到 `C:\Windows\System32\drivers\TAS2XXX38BA.bin`、
   重新初始化 `ACPI\TIAS2781\0`。
3. 想连音色一起调：装 Equalizer APO，把 `eq/presets/D-warm.txt` 写进
   `C:\Program Files\EqualizerAPO\config\config.txt`。
4. 完整分析（频响、限幅拐点、为什么 EQ 抬不动低音）在 `REPORT.md`。

## 开源与隐私

本仓库以 MIT 许可公开（脚本与文档部分），二进制固件的版权归原厂，详见 `NOTICE.md`。
仓库中已移除机器序列号、主机名、用户目录等个人信息；音频端点 GUID 已做匿名化处理。
