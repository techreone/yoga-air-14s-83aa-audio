# 存档清单 · Yoga Air 14s 2023 (83AA) 音频栈

本仓库是这台 **Lenovo Yoga Air 14s 2023 工程样机（EA 版，Model 83AA）** 的音频驱动 / 固件 / 调音全量存档。
目的：这台机器的 6 扬声器只有配对的固件才能正常出声，而这些文件在网上已经很难再找回来。

- 机器：`LENOVO 83AA`，SKU `LENOVO_MT_83AA_BU_idea_FM_YogaAir 14s APU8`
- 声卡：`HDAUDIO\FUNC_01&VEN_10EC&DEV_0287&SUBSYS_17AA38BA&REV_1000`（Realtek ALC287，SSID **17AA38BA**）
- 功放：`ACPI\TIAS2781\0`（TI TAS2781 ×4，SUBSYS `17AA38BA`，走 `ACPI\AMDI0010\3` I2C）
- 零售孪生型号：Yoga Slim 7 14APU8（83AA），其 SSID 为 **17AA38BB**

## 这台机器上真正起作用的是什么

音量"像蚊子叫"的根因不在 Realtek 驱动，而在 **TI 功放的 DSP 固件**：

| 固件 | 大小 | MD5 | 内部标识 | 表现 |
| --- | --- | --- | --- | --- |
| `TAS2XXX38BA.bin` v4.0 | 64,536 | `AE9E2EA9B5E41E8787FF3BE992143ACF` | `S780-14_Quad-PM2_YC_v4.0_20221113` | **能正常出声**（EA 时期） |
| `TAS2XXX38BA.bin` v8.0 | 64,732 | `9AC11639F1B66EBE6CBBE4446B9E630C` | `Zs780-14AIR-quad-pm2-YC-v8.0-SS4-20230313` | 声音极小、失真 |
| `TAS2XXX38BA.bin` 零售版 | 64,732 | `FCAA167BB712CBE7829AE41F9EA7BFA0` | 无（2023-09 起新格式） | 声音极小、失真 |
| `TAS2XXX38BB.bin` 零售 38BB | 64,504 | `9A6089A79EF6038691733A18C94C1005` | `S780-14AIR-AAC-pm1-quad-v10.1-20230322-SS13-alpha6` | 未在 38BA 上测试 |

关键机制：**联想的安装包只把固件写进 DriverStore，不覆盖运行时路径**
`C:\Windows\System32\drivers\TAS2XXX38BA.bin`。所以"重装/降级驱动"看起来毫无变化——
真正被加载的固件一直是旧的那一份。改这个文件 + 重新初始化设备才会生效。

## 当前已验证可用的组合

| 组件 | 版本 | 备注 |
| --- | --- | --- |
| TI Smart Amplifier 驱动 | `1.3.29.0`（`oem39.inf`，2022-11-13） | 来自 2023-02 的 `mmy5017` 包 |
| Realtek 声卡驱动 | `6.0.9553.1`（`oem5.inf`，2023-07-25） | Windows 不允许降级绑定，保持新版即可 |
| 运行时功放固件 | v4.0，64,536 B | `archive/runtime/TAS2XXX38BA.bin` |
| Equalizer APO | 1.4.2 | 仅绑定「扬声器 (Realtek(R) Audio)」端点 |

## 存档内容

```
archive/
  driverstore/     从 C:\Windows\System32\DriverStore\FileRepository 抽出的音频相关驱动包
                   （tas2xxx / hdxacplv / hdx_lenovoext / dax3 / realtekapo / realtekservice /
                     elevocapo 的 INF+CAT / amdacpafd / atihdwt6）
  runtime/         运行时实际加载的固件与 TAS2xxx.sys
  system/          机器信息、设备与驱动版本、pnputil 枚举、TI 注册表键、音频端点
  skipped-files.csv 因体积过大未入库的文件清单（都在下面的官方安装包里）
firmware/          三代 38BA 固件 + 38BB 零售固件（已重命名带版本与大小）
eq/                Equalizer APO 预设、切换脚本、安装说明
scripts/           archive-drivers.ps1 / snapshot-system.ps1 / apply-firmware.ps1 /
                   revert-firmware.ps1 / install-ea-stack.ps1
REPORT.md          完整分析报告（频响、限幅拐点、结论）
```

`archive/driverstore/*/RTAIODAT.DAT`（54–56 MB 的 Realtek 调音库）**未入库**，
它就在下面的官方安装包里，用 SHA256 校验即可。

## 官方安装包（联想，长期可下）

| 日期 | 版本 | 文件 | 大小 | SHA256 |
| --- | --- | --- | --- | --- |
| 2025-09-02 | 6.0.9553.1 | `kxks047f5xecgff0.exe` | 149,970,112 | `F4E251806690818DB6F5C796C2569515EBA7E912C8A455B90E654EB4B91131E7` |
| 2023-10-18 | 6.0.9553.1 | `kxks037f5xecgff0.exe` | 149,553,528 | `695149D8BF07912E422F9BD271C16F1DABE58EE5E9211C4B3D1B5718E758D874` |
| 2023-09-01 | 6.0.9503.1 | `kxks027f5xecgff0.exe` | 149,100,064 | `6737D75FB87A37C02345A3948DB2F9BF2B4934D6E6A343DC9BBD35C58DCD3265` |
| 2023-07-07 | 6.0.9456.1 | `kxks017f5xecgff0.exe` | 148,989,312 | `6940DB662065DF489F2D3DBBC2D3B37698CCD3FBDFFBAEDE05734A8CE92D854F` |
| 2023-02（CN） | 6.0.9445.1 | `audio-MMY5017FZDE18AF0.exe` | 131,180,608 | `F710CF13CE561CF7C467237C3C54DE43D8AFF0FB212591E55EB35ACC7ECF7D84` |

- 全球页：<https://support.lenovo.com/us/en/downloads/ds564425-audio-driver-for-windows-11-64-bit-yoga-slim-7-14apu8>
- 直链前缀：`https://download.lenovo.com/consumer/mobiles/<文件名>`
- 中文详情页（含历史版本）：<https://newsupport.lenovo.com.cn/driveDownloads_detail.html?driveId=147746>
- `mmy5017` 原始链接：`https://newdriverdl.lenovo.com.cn/newlenovo/alldriversupload/106808/audio-MMY5017FZDE18AF0.exe`
  （中文站的链接带时效 token，失效后到上面的详情页重新取）

这几个包都是 **Inno Setup 5.5.7**，可用 `innoextract` 解包：
`winget install dscharrer.innoextract`，然后 `innoextract -e -d out <包名>.exe`。
注意：解包只得到 DriverStore 内容，**运行时固件仍需手工放到 `C:\Windows\System32\drivers\`**。

## 恢复步骤（换机 / 重装系统）

1. 装 2025 官方音频包 `kxks047f5xecgff0.exe`，重启。
2. 把 `firmware/TAS2XXX38BA_v4.0_20221113_64536B.bin` 覆盖到
   `C:\Windows\System32\drivers\TAS2XXX38BA.bin`（该文件属主是 TrustedInstaller，
   先 `takeown /f` + `icacls ... /grant "*S-1-5-32-544:F"`）。
3. 删除 `HKLM\SYSTEM\TIUpdateInformation`，然后禁用再启用 `ACPI\TIAS2781\0`，
   让驱动重新下发固件；确认 `lastUpdateFwStatus = Status 0x0`。
4. 装 `mmy5017` 包里的 TI 驱动 `1.3.29.0`（可选，比 1.10.2.1 低频多 1–2 dB）。
5. 装 Equalizer APO 1.4.2，只勾选「扬声器 / Realtek(R) Audio」，写入 `eq/presets/D-warm.txt`
   到 `C:\Program Files\EqualizerAPO\config\config.txt`。

一键脚本见 `scripts/install-ea-stack.ps1`（需管理员）。

## 已知边界

- 100 Hz 以下受功放限幅器硬限制：信号端 +11 dB 只能换来 +0.8 dB，EQ 抬不动低音。
- 4–8 kHz 有 APO 固定 +4.5 dB 提升，是"尖"的电学来源，靠 EQ 削减。
- 麦克风阵列采集链路在 100 Hz 以下不可信（静音段是纯数字零，采集侧有门限）。
