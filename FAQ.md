# 常见问题（FAQ）

> 针对 Lenovo XiaoXinAir 14ITL 2021（i5-1155G7 / Iris Xe）· macOS Tahoe 26.7.1。
> 更完整的配置说明见 [EFI/README.md](EFI/README.md)。

## 目录

1. [为什么必须是 26.7.1，不能升 26.7.2？](#1-为什么必须是-2671不能升-2672)
2. [声音：外放/耳机没声音，OCLP 里也没有 "Modern Audio" 怎么办？](#2-声音外放耳机没声音oclp-里也没有-modern-audio-怎么办)
3. [OCLP 需要给显卡打补丁吗？](#3-oclp-需要给显卡打补丁吗)
4. [Wi-Fi 为什么没有系统图标？只能用 HeliPort 吗？](#4-wi-fi-为什么没有系统图标只能用-heliport-吗)
5. [外接显示器（HDMI / USB-C）为什么不可用？](#5-外接显示器hdmi--usb-c为什么不可用)
6. [合盖或关屏后唤醒黑屏怎么办？](#6-合盖或关屏后唤醒黑屏怎么办)
7. [重装系统后触摸板失灵](#7-重装系统后触摸板失灵)
8. [蓝牙一直 Off，芯片显示 BCM_4350C2](#8-蓝牙一直-off芯片显示-bcm_4350c2)
9. [电池显示 1%，电压/容量读不到](#9-电池显示-1电压容量读不到)
10. [三码已清空，怎么正常使用 iMessage / App Store？](#10-三码已清空怎么正常使用-imessage--app-store)

---

## 1. 为什么必须是 26.7.1，不能升 26.7.2？

WhateverXe 0.6.1 的图形栈只匹配 **26.7.1（build 25G241）**。
26.7 是 `25G229`，26.7.2 是 `25G332`，ABI 不一致时 `-allow3d` 会直接 panic
（`IOAccelTask::release` / `IOAcceleratorFamily2`）。

升级前先确认：

```bash
sw_vers -buildVersion
```

结果必须是 `25G241`。如果 WEX 后续版本明确支持了别的 build，再考虑升级系统。

---

## 2. 声音：外放/耳机没声音，OCLP 里也没有 "Modern Audio" 怎么办？

**原因**：macOS 26 移除了 `AppleHDA.kext`，AppleALC / VoodooHDA 都无法单独工作，
必须用 OCLP 的 **Modern Audio** 根补丁把 `AppleHDA` 恢复回来。

但 OCLP 的机型表里，只有 `SecureBootModel is None` 的机型才会显示这个补丁。
`MacBookPro16,1` 是 T2 机型（`SecureBootModel = "j152f"`），会被直接跳过；
`MacBookPro11,4` 是 `None`，所以能看到补丁。

**做法（临时换机型 → 打补丁 → 换回来）**：

1. 备份 EFI 和当前 config。
2. 把 `PlatformInfo > Generic > SystemProductName` 临时改成 `MacBookPro11,4`
   （同时需要一套能通过校验的 Serial / MLB / UUID，改动前先记下原值）。
3. 确认以下条件：
   - `Misc > Security > SecureBootModel = Disabled`
   - `NVRAM > csr-active-config = 03080000`
   - 加载 `AMFIPass.kext` 1.4.1 Mod（`-amfipassbeta` 视版本需要）
   - 安装与系统 build 对应的 KDK（本机为 `KDK_26.7.1_25G241.kdk`）
4. 使用 WhateverXe 作者的定制版 OCLP：
   `b00t0x/OpenCore-Legacy-Patcher` **3.0.0-rc.3+m.3**（普通版签名链不匹配）。
5. OCLP → Post-Install Root Patch → 应用 → 重启。
6. 确认 `AppleHDA.kext` 已恢复、`AppleHDAController` 已加载，外放有声音。
7. 把 SMBIOS 改回 `MacBookPro16,1`，重启。

**验证**：

```bash
ls /System/Library/Extensions/AppleHDA.kext
kextstat | grep -i AppleHDA
defaults read /System/Library/CoreServices/OpenCore-Legacy-Patcher.plist 2>/dev/null
```

本机声卡是 **Realtek ALC257**（`0x10EC0257`），使用 `layout-id=11` + `alcid=11`。
外放和耳机麦克风正常；**内置麦克风是 DMIC（SoundWire），macOS 无驱动，无解**。

> 换回 `MacBookPro16,1` 后补丁继续有效，因为根补丁写在系统卷里，与当前 SMBIOS 无关。
> 但每次系统更新后可能需要重新打一次。

---

## 3. OCLP 需要给显卡打补丁吗？

**不需要。**

- 显卡加速由 **WhateverXe 0.6.1 + `-allow3d`** 提供（Iris Xe / Metal 2 / 1536MB）。
- OCLP 上游已经移除了 Iris Xe 的根补丁，装 OCLP 也不会让核显更好。
- 本机的 OCLP **只用于声卡的 Modern Audio**。

不要为了"让 OCLP 更完整"去装其它根补丁，容易和 WEX 的图形栈冲突。

---

## 4. Wi-Fi 为什么没有系统图标？只能用 HeliPort 吗？

**官方现状（2026-11 核对）**：

| 项目 | 最新版本 | 仓库状态 |
| --- | --- | --- |
| `OpenIntelWireless/itlwm` | v2.3.0（2024-06-09） | 2024-07-12 后无提交，不支持 Tahoe 原生 |
| `OpenIntelWireless/HeliPort` | v1.5.0（2024-08-01） | alpha 2.0.0 仅改 UI，驱动能力不变 |

所以在 Tahoe 上，官方路线只有：

```text
itlwm.kext（隐藏网卡）+ HeliPort（客户端）
```

没有系统 Wi-Fi 菜单/图标是正常的，不是配置错误。本机使用的就是
`itlwm 2.3.0` + `HeliPort 1.5.0`，已是最新稳定组合。

**社区实验方案**：`kgp-macPro/AirportItlwm-Tahoe` v2.0.0（2026-11-06）
支持 AX201 / AX210 / AX211 / BE200，可以提供原生 Wi-Fi 集成，但代价很高：

1. 必须搭配 **OCLP-CustoMac 3.0.0+** 打根补丁，恢复 Ventura 的
   `IO80211FamilyLegacy` 无线框架——不是"只换一个 kext"。
2. 必须启用 **AppleVTD**（`DisableIoMapper=false` + 可用 DMAR）。
   本机当前是 `DisableIoMapper=true`，打开后 Thunderbolt / USB / XHCI
   都可能受影响，需要逐项验证。
3. AX201 只验证了 VHT，HE/BF 尚未验证；AWDL / AirDrop / 接力仍有问题
   （对应 itlwm issue #1062）。
4. 它和本机现有的 OCLP Modern Audio 根补丁属于两套补丁栈，存在互相覆盖、
   声卡被打回原形的风险。

**建议**：日常使用保持 `itlwm + HeliPort`。如果一定要试原生方案，
先完整备份 EFI 和系统盘，单独验证 AppleVTD 不影响其它设备，再上根补丁；
失败就回滚 EFI + 卸载根补丁 + 换回 itlwm 2.3.0 + HeliPort 1.5.0。

---

## 5. 外接显示器（HDMI / USB-C）为什么不可用？

属于 **WhateverXe 驱动限制**，不是线材或设置问题：

- 板载 HDMI（DDI 1）：`AUX ddi = 1 Time out: 0x5d40023f`，`sinkCount = 0`；
  拔掉线日志照旧刷，说明 DDI 1 的 AUX 通道在驱动层就没起来。
- USB-C DP（DDI 3）：能读到 `sinkCount = 1`，但 link training / modeset 不完成，
  不生成 `display0`；冷启动时干脆识别不到。

`-nopsr` / `-noDC9` / `-noAUXDelay` 都实测无效，已回滚。
详细日志见 [EFI/README.md 文末](EFI/README.md#附加2026-11-04-23302359外接显示实测不可用)。

---

## 6. 合盖或关屏后唤醒黑屏怎么办？

**不要主动关屏**（`pmset displaysleepnow` 或系统设置里的"关闭显示器"），
会触发 WEX 的 AUX 超时 → 链路训练失败 → 黑屏，只能长按电源键。

**合盖可以**，但前提是整机不睡眠：

```bash
sudo pmset -a sleep 0 displaysleep 0 disksleep 0 \
              hibernatemode 0 standby 0 autopoweroff 0 powernap 0 \
              disablesleep 1
```

注意：`SleepDisabled` 每次开机都会被 `powerd` 清回 0，一次性脚本追不上。
必须用常驻 LaunchDaemon（每 2 秒校验）。安装方法见
[power-policy/README.md](power-policy/README.md)。

重装系统后这两个文件（`/usr/local/bin/xiaoxin-power-policy.sh`、
`/Library/LaunchDaemons/local.xiaoxin.powerpolicy.plist`）需要重新放置。

---

## 7. 重装系统后触摸板失灵

触摸板不只看 EFI，还依赖系统盘里的 5 个 Voodoo kext 和重建后的 AuxKC：

```text
/Library/Extensions/
  VoodooI2C.kext 2.9.1（含 Tiger Lake PCI ID 0xA0E8 补丁）
  VoodooGPIO.kext 1.1
  VoodooI2CServices.kext
  VoodooInput.kext 1.1.7
  VoodooI2CHID.kext

/Library/KernelCollections/AuxiliaryKernelExtensions.kc
```

操作步骤见 [命令.md](命令.md)。关键是 5 个 kext 必须齐全，然后用
`kmutil create -n aux` 重建并重启；`kmutil install --update-all` 在 Tahoe 上必失败。

本机走 polling 模式（boot-args `-vi2c-force-polling`），因为 VoodooGPIO 1.1
没有 Tiger Lake 的 GPIO 类。

---

## 8. 蓝牙一直 Off，芯片显示 BCM_4350C2

官方 `IntelBTPatcher` 2.4.0（2024-02）的内核版本上限是 Sequoia，在 Tahoe 上
会直接放弃打补丁 → `bluetoothd` 崩溃循环（`EXC_GUARD`）→ 蓝牙永远 Off，
系统报告里显示 `BCM_4350C2` 是"没被接管"的假象。

修复三件套：

| Kext | 版本 |
| --- | --- |
| `IntelBluetoothFirmware.kext` | 2.5.3（lshbluesky 的 Tahoe build） |
| `IntelBTPatcher.kext` | 2.5.3（同上） |
| `BlueToolFixup.kext` | 2.7.2（官方） |

NVRAM 的 `Add` 和 `Delete` 都要加（GUID `7C436110-AB2A-4BBB-A880-FE41995C9F82`）：

```text
bluetoothExternalDongleFailed   = 00
bluetoothInternalControllerInfo = 0000000000000000000000000000（14 字节）
```

再保留 boot-arg `-btlfxallowanyaddr`。**不要**装 `IntelBluetoothInjector.kext`。

---

## 9. 电池显示 1%，电压/容量读不到

通常是 ACPI 里误用了别的机型的电池补丁：

- `1of2 - Rename _BIF to XBif`
- `2of2 - Rename _BST to XBST`

这两条是给 Yoga 的 `H_EC` 电池 SSDT 预留的。本机电池是
`\_SB.PC00.LPCB.EC0` + `BAT1`，改名后没有驱动接管 `_BST`，就会只剩设计容量。

**修复**：禁用这两条重命名，保留 `ECEnabler.kext`（16-bit EC 字段读取），
重启即可。不要启用 `SSDT-OCBAT1-YOGA14S2021.aml` / `SSDT-BATS-YOGA14S2021.aml`。

---

## 10. 三码已清空，怎么正常使用 iMessage / App Store？

仓库里的 EFI 已清空 `SystemSerialNumber` / `MLB` / `SystemUUID` / `ROM`
（并移除了含 Windows 密钥的 `MSDM` 表）。

直接开机没问题，但 iMessage / App Store / 查找我的需要一套自己的三码：

1. 用 [GenSMBIOS](https://github.com/corpnewt/GenSMBIOS) 选择 `MacBookPro16,1` 生成；
2. 填入 `PlatformInfo > Generic`；
3. `ROM` 用本机网卡 MAC 生成（12 位十六进制）；
4. 不要多台机器共用同一套三码。
