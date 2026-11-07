# 联想小新 Air 14ITL 2021 · 黑苹果（macOS Tahoe 26.7.1）

> Lenovo XiaoXinAir 14ITL 2021（82FF0009CD）· i5-1155G7 / Iris Xe 80EU · 16GB · WD SN730
> macOS Tahoe 26.7.1 (25G241) · OpenCore 1.0.0 · SMBIOS MacBookPro16,1

## 功能状态

| 状态 | 功能 | 说明 |
| --- | --- | --- |
| ✅ | 显卡加速 | Iris Xe / Metal 2 / 1536MB（WhateverXe 0.6.1 + `-allow3d`） |
| ✅ | 电池 | 正常 |
| ✅ | 声音 | 外放 + 耳机麦（OCLP Modern Audio + AppleALC `layout-id=11`） |
| ✅ | Wi-Fi | itlwm + HeliPort |
| ✅ | 蓝牙 | Intel AX201（Tahoe 专用 kext + NVRAM 变量） |
| ✅ | 触摸板 | I2C `0x2C` + polling 模式 |
| ✅ | 合盖 | 不睡眠、硬件关屏、开盖即亮（常驻电源守护，重启自动生效） |
| ❌ | 外接显示 | 板载 HDMI 与 USB-C DP 均不可用（WEX 驱动限制） |
| ❌ | 内置麦克风 | DMIC，硬件无解 |
| ⚠️ | 主动关屏 | 显示休眠唤醒黑屏（WEX 上游缺陷，已禁用睡眠规避） |
| ⚠️ | 引导界面键盘 | `KeySupportMode=V2`，未验证 |

## 目录结构

```text
.
├── README.md                                本文件
├── FAQ.md                                   常见问题（声音 / Wi-Fi / 外接显示 / 蓝牙等）
├── EFI/                                     已脱敏的完整 EFI（OpenCore / kexts / ACPI）
│   └── README.md                            EFI 详细说明与关键改动
├── checksums.txt                            EFI 内全部文件的 SHA-256
├── 命令.md                                  触摸板 AuxKC 重建命令（历史记录）
├── power-policy/                            电源守护（防合盖睡眠 → 唤醒黑屏）
│   ├── README.md
│   ├── xiaoxin-power-policy.sh
│   └── local.xiaoxin.powerpolicy.plist
├── config.plist.*                           config 历史快照（已脱敏）
├── verify-touchpad.sh / verify-bluetooth.sh 验证脚本
├── wake-monitor*.sh / test-display-sleep.sh 休眠/唤醒诊断脚本
└── logs/                                    诊断日志归档
```

> 原始 ACPI dump（`SysReport-原始ACPI`）未包含在仓库里 —— 它属于调试材料，
> 且可能带有硬件标识。需要时请自行用 OpenCore 的 SysReport 重新导出。

## 快速链接

- [常见问题（FAQ）](FAQ.md)
- [EFI 详细说明](EFI/README.md)
- [电源守护说明](power-policy/README.md)
- [触摸板 AuxKC 重建命令](命令.md)

## 关键要点

- **触摸板**：两条 DSDT `_CRS` 补丁 + `-vi2c-force-polling` + 系统盘 AuxKC
- **蓝牙**：IntelBluetoothFirmware / IntelBTPatcher 2.5.3（Tahoe build）+ BlueToolFixup 2.7.2
- **合盖**：`SleepDisabled` 每次开机都会被 `powerd` 清 0，必须用常驻守护（每 2 秒校验）
- **只恢复 EFI 不够**：触摸板依赖 `/Library/Extensions` + AuxKC，声音依赖 OCLP Modern Audio 根补丁

## 已知限制

外接显示、主动关屏、AirDrop/Handoff 在本机不可用；原因与实测日志见
[EFI/README.md 文末](EFI/README.md#附加2026-11-04-23302359外接显示实测不可用)，
Wi-Fi 与其它常见问题见 [FAQ.md](FAQ.md)。

## 关于三码

EFI 备份中的三码（`SystemSerialNumber` / `MLB` / `SystemUUID` / `ROM`）已全部清空，
同时移除了原始 ACPI dump 里含 Windows 产品密钥的 `MSDM` 表。

直接使用这套 EFI 可以正常开机，但 **iMessage / App Store / 查找我的** 等功能
需要你用自己的设备生成三码（推荐 [GenSMBIOS](https://github.com/corpnewt/GenSMBIOS)），
填入 `PlatformInfo > Generic` 后再使用，避免多台机器共用同一身份。

## 免责声明

本项目仅为个人设备折腾记录，不保证适用于其他机型。操作涉及系统分区与内核扩展，请自行备份。
