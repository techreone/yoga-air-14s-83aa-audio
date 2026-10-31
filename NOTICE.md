# NOTICE / 版权说明

本仓库是一个**个人设备恢复存档**，不是联想、Realtek、Texas Instruments、Dolby 或 Elevoc 的官方发布渠道。

- `firmware/`、`archive/driverstore/`、`archive/runtime/` 中的二进制文件版权归各自厂商所有
  （Lenovo / Realtek Semiconductor / Texas Instruments / Dolby Laboratories / Elevoc 等），
  它们是从本机已安装的驱动包与联想官方下载站中提取出来的，仅为让同型号设备的主人能够
  修复自己的机器。
- `REPORT.md`、`MANIFEST.md`、`scripts/`、`eq/` 下的文本与脚本由本仓库作者编写，采用 MIT 许可证。
- 如果你是该文件的版权方并希望它被移除，请开 issue，我会立刻删除。

## 关于机型

Lenovo Yoga Air 14s 2023（工程样机，Model `83AA`，SSID `17AA38BA`）与零售的
Yoga Slim 7 14APU8（SSID `17AA38BB`）共用同一套 Realtek 驱动，但**功放固件不同**。

本仓库记录的 v4.0 固件（`S780-14_Quad-PM2_YC_v4.0_20221113`）是能让这台样机
6 扬声器正常出声的版本；零售机请优先使用联想官方安装包里的固件。
