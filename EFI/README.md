# 联想小新 Air 14ITL 2021 · macOS Tahoe 26.7.1 黑苹果 EFI

> **备份时间**：2026-11-04 23:30（CST）
> **备份来源**：120GB 外置安装盘 ESP（`disk2s1`）→ `/Volumes/EFI/EFI`
> **状态**：显卡 / 电池 / 声音 / Wi-Fi / 蓝牙 / 触摸板 / 合盖 全部可用

## 机器

| 项目 | 内容 |
| --- | --- |
| 机型 | Lenovo XiaoXinAir 14ITL 2021（82FF0009CD） |
| CPU / 核显 | i5-1155G7 / Iris Xe 80EU |
| 内存 / 硬盘 | 16GB / WD SN730 512G |
| SMBIOS | MacBookPro16,1 |
| Serial / MLB | 已清空（使用前请用 [GenSMBIOS](https://github.com/corpnewt/GenSMBIOS) 生成自己的） |
| 网卡 | Intel AX201（Wi-Fi + 蓝牙） |

> ⚠️ **本 EFI 已清空三码**（`SystemSerialNumber` / `MLB` / `SystemUUID` / `ROM`）。
> 直接使用可以正常开机，但 iMessage、App Store 等依赖设备身份的功能需要你
> 自己生成一套三码后填入 `PlatformInfo > Generic`，否则多台机器会共用同一身份。

## 系统

- macOS Tahoe **26.7.1 (25G241)**
- OpenCore **1.0.0**
- 引导：外置盘 ESP（内置盘 `disk0s1` 仍是 `SYSTEM_DRV`/Windows 引导）
- 时区：`Asia/Shanghai`

## 功能状态

| 状态 | 功能 | 说明 |
| --- | --- | --- |
| ✅ | 显卡 | Iris Xe / Metal 2 / 1536MB（WhateverXe 0.6.1 + `-allow3d`） |
| ✅ | 电池 | 正常（已关闭 `_BIF`/`_BST` 重命名） |
| ✅ | 声音 | 外放 + 耳机麦（OCLP Modern Audio 根补丁 + AppleALC `layout-id=11`） |
| ❌ | 内置麦克风 | DMIC，硬件无解 |
| ✅ | Wi-Fi | itlwm 2.3.0 + HeliPort 1.5.0 |
| ✅ | 蓝牙 | AX201，`THIRD_PARTY_DONGLE`，可配对连接 |
| ✅ | 触摸板 | I2C `0x2C`，polling 模式 |
| ✅ | 合盖 | 合盖不睡眠、硬件关屏、开盖即亮（常驻守护钉住 `SleepDisabled=1`，重启自动生效） |
| ❌ | 外接显示 | 板载 HDMI 与 USB-C DP 均不可用（WEX 限制，见文末） |
| ⚠️ | 主动关屏 | 显示休眠唤醒黑屏（WEX 上游缺陷，见文末） |
| ⚠️ | 引导键盘 | `KeySupportMode=V2`，未验证 |

---

## 关键改动 1：触摸板（ACPI Patch，必须保留）

`TableSignature = DSDT`，`Count = 1`

```text
a. Comment: TPAD _CRS skip OSYS<0x07DC early return
   Find:    95 4F 53 59 53 0B DC 07 A4 53 42 46 49
   Replace: 95 4F 53 59 53 0B 00 00 A4 53 42 46 49

b. Comment: TPAD _CRS: return SBFB+SBFG (I2C + GPIO int)
   Find:    A0 0D 00 A4 84 53 42 46 42 53 42 46 47
   Replace: A0 0D 01 A4 84 53 42 46 42 53 42 46 47
```

**原理**：本机 `TPAD._CRS` 是

```asl
If (OSYS < 0x07DC) Return (SBFI)      // 只有中断，没有 I2C 描述符
If (Zero)          Return (SBFB+SBFG) // 死代码
Return (SBFB + SBFI)
```

macOS 下 `OSYS` 恒为 `0x03E8`（因为没有 `_OSI→XOSI` 补丁），只返回 `SBFI`，
VoodooI2C 找不到 `0x8E` I2C 描述符 → nub 初始化失败 → `VoodooI2CHID` 不加载。

这两条只改 `TPAD` 自身，不动全局 `OSYS`（避免影响电池/散热等 39 处分支）。
地址 `0x2C` 是运行时由 `CreateWordField(SBFB, 0x10, ADR0)` 写入的。

配合 boot-args：`-vi2c-force-polling`（原因见改动 3）。

---

## 关键改动 2：蓝牙（Tahoe 专用）

官方 IntelBTPatcher 2.4.0（2024-02）内置内核版本上限是 Sequoia，
在 Tahoe 上直接失效 → `bluetoothd` 崩溃循环（`EXC_GUARD`）→ 蓝牙永远 Off / `BCM_4350C2`。

**修复：**

| Kext | 版本 | 备注 |
| --- | --- | --- |
| `IntelBluetoothFirmware.kext` | 2.5.3 | lshbluesky 的 Tahoe build |
| `IntelBTPatcher.kext` | 2.5.3 | 同上 |
| `BlueToolFixup.kext` | 2.7.2 | 保持官方版本 |

> ✗ 不要装 `IntelBluetoothInjector.kext`（与 BlueToolFixup 冲突）

**NVRAM**（`Add` 和 `Delete` 都要加）：

```text
GUID 7C436110-AB2A-4BBB-A880-FE41995C9F82
  bluetoothExternalDongleFailed   = 00
  bluetoothInternalControllerInfo = 0000000000000000000000000000（14 字节）
```

> ⚠️ OpenCore 的 `NVRAM > Delete` 是 `{GUID: [变量名...]}` 的字典，不是数组。

**实测结果**：`Address F0:9E:4A:61:C0:19` / `State On` / `Firmware v8787` / 崩溃报告 0

**来源：**

- <https://github.com/OpenIntelWireless/IntelBluetoothFirmware/issues/505>
- <https://github.com/lshbluesky/IntelBluetoothFirmware/releases>（v2.5.3）

---

## 关键改动 3：触摸板为什么用 polling

`GPI0`（`_HID = INT34C5`）需要 `VoodooGPIOTigerLakeLP` 类，但 VoodooGPIO 1.1 的
二进制里没有这个类（所谓"魔改版"只改了 `Info.plist` 的匹配列表，
所以日志里出现 `Could not find GPIO controller, exiting`）。

加 `-vi2c-force-polling` 让 nub 跳过 GPIO，HID 驱动改走轮询。

---

## ⚠️ 重要：只恢复 EFI 不够

触摸板依赖系统盘：

```text
/Library/Extensions/
  VoodooI2C.kext 2.9.1（已打 Tiger Lake PCI ID 0xA0E8 补丁）
  VoodooGPIO.kext 1.1
  VoodooI2CServices.kext
  VoodooInput.kext 1.1.7
  VoodooI2CHID.kext
  AppleIntelTGLCompat.kext / AppleIntelTGLGraphics.kext /
  AppleIntelTGLGraphicsFramebuffer.kext（WEX 图形栈）

/Library/KernelCollections/AuxiliaryKernelExtensions.kc
  （kmutil create -n aux 重建；OC 里 VoodooI2C 注入已全部禁用）

声音依赖 OCLP 的 Modern Audio 根补丁（AppleHDA）
```

蓝牙完全在 EFI 里（kext + NVRAM），恢复 EFI 即可。

**重装系统后：**

1. 把 5 个 Voodoo kext 拷到 `/Library/Extensions`
2. 重建 AuxKC（配方见仓库根目录 [命令.md](../命令.md)）
3. 装 WEX Graphics pkg（0.3.2）
4. 装 OCLP Modern Audio 根补丁
5. 重启

---

## 恢复 / 部署

**覆盖外置盘 ESP：**

```bash
sudo diskutil mount disk2s1
sudo ditto EFI /Volumes/EFI/EFI
diskutil unmount disk2s1
```

**写内置盘 ESP（脱离 U 盘，与 Windows 共存）：**

```bash
sudo diskutil mount disk0s1        # 当前是 SYSTEM_DRV
# 保留 /Volumes/SYSTEM_DRV 里的 EFI/Microsoft，
# 把本 EFI 的 BOOT/OC 合并进去，再用 BIOS 指向该 ESP
```

---

## 关键配置摘要

**boot-args：**

```text
-v keepsyms=1 -no_compat_check -allow3d -disablegfxfirmware \
-btlfxallowanyaddr -igfxdvmt debug=0x100 alcid=11 -vi2c-force-polling
```

**DeviceProperties：**

```text
PciRoot(0x0)/Pci(0x2,0x0):
  framebuffer-patch-enable = 01000000
  framebuffer-stolenmem    = 0000c003
  hda-gfx                  = onboard-1

PciRoot(0x0)/Pci(0x1f,0x3):
  layout-id = 0b000000 (11)
```

**NVRAM：**

```text
boot-args（同上）
bluetoothExternalDongleFailed   = 00
bluetoothInternalControllerInfo = 14 字节 0
csr-active-config = 03080000
prev-lang:kbd     = en-US:0
```

**ACPI 启用：**

```text
SSDT-AWAC / SSDT-EC-USBX-LAPTOP / SSDT-HPET / SSDT-PNLF-CFL /
SSDT-RHUB / SSDT-UIAC / SSDT-NameS3-disable / SSDT-PLUG-_SB.PR00 /
SSDT-OCGPI0-GPHD / SSDT-OC-XOSI
```

**ACPI 禁用：**

```text
SSDT-PLUG / SSDT-OCBAT1-YOGA14S2021 / SSDT-BATS-YOGA14S2021 /
SSDT-OCI2C-TPXX-YOGA14S2021 / SSDT-TPD0-GPIO-YOGA14S2021
```

**ACPI Patch 共 9 条：**

- 禁用：`_BIF→XBIF`、`_BST→XBST`
- 启用：HPET `_CRS→XCRS`、RTC IRQ8、TIMR IRQ0、`PNLF→XNLF`、`_S3_→XS3_`、
  `TPAD skip OSYS`、`TPAD return SBFB+SBFG`（后两条是本机新增）

`OC/Kexts` 里 VoodooI2C 相关条目全部禁用（走 `/Library/Extensions` + AuxKC）。

---

## ⚠️ 系统电源策略（不在 EFI 里，重装后必须重设）

```bash
sudo pmset -a sleep 0 displaysleep 0 disksleep 0 \
              hibernatemode 0 standby 0 autopoweroff 0 powernap 0 \
              disablesleep 1
```

`SleepDisabled = 1`（持久化于 `/Library/Preferences/com.apple.PowerManagement.plist`）

### 重要（2026-11-05 发现并修复）

上面这条 `pmset` 虽然立即生效，但 **每次开机 `powerd` 初始化时都会把
`SleepDisabled` 清回 0**（plist 也写回 `false`）→ 合盖就会真的睡眠 → 唤醒黑屏。

一次性脚本 / 延迟脚本都追不上（实测 `00:37:20` 设置，`00:37:29` 被清回）。
所以改成**常驻循环守护**（`KeepAlive`，每 2 秒校验一次）：

```text
/usr/local/bin/xiaoxin-power-policy.sh
/Library/LaunchDaemons/local.xiaoxin.powerpolicy.plist
日志：/var/log/xiaoxin-powerpolicy.log
```

**安装**（重装系统后必须重做，文件副本在仓库根目录的 [`power-policy/`](../power-policy/) 里）：

```bash
sudo cp xiaoxin-power-policy.sh /usr/local/bin/
sudo chmod 755 /usr/local/bin/xiaoxin-power-policy.sh
sudo xattr -c /usr/local/bin/xiaoxin-power-policy.sh

sudo cp local.xiaoxin.powerpolicy.plist /Library/LaunchDaemons/
sudo chown root:wheel /Library/LaunchDaemons/local.xiaoxin.powerpolicy.plist
sudo chmod 644 /Library/LaunchDaemons/local.xiaoxin.powerpolicy.plist

sudo launchctl load -w /Library/LaunchDaemons/local.xiaoxin.powerpolicy.plist
```

> 新版 `launchctl bootstrap system` 在本机报 `Input/output error`，用旧式 `load -w` 正常。

**验证**（2026-11-05 00:45 重启后实测）：

```text
pmset -g | grep SleepDisabled    → 1          ✅
launchctl list | grep xiaoxin    → 有 PID      ✅
手动改 0 → 2~4 秒内自动回到 1                  ✅
开机后 launchd 自动拉起（runs = 1，KeepAlive）  ✅
```

### 原因（显示休眠唤醒黑屏，WEX 上游缺陷）

主动关屏后唤醒，驱动日志：

```text
[IGFB][ERROR][AUX] ddi = 0 Time out: 0x5d40023f
[IGFB][ERROR][LINK_TRAINING] Phase 1 of link training failed
[IGFB][ERROR][DISPLAY] FB0: Hardware mode set failed / FB0 is not enabled
```

即 AUX 通道未恢复 → 链路训练失败 → 显示器被标记 offline。

已排除：背光（`bklt` 恒 65403）、PSR（`-nopsr` 无效）、DVMT（60MB + `-igfxdvmt` 正确）。
WEX README 明确：*full system sleep/wake unverified*。

**合盖实测通过（2026-11-04 23:19）：**

```text
合盖全程 framebuffer CurrentPowerState=2，pmset 无 "Display is turned off"
→ macOS 不走显示休眠，面板由 EC 断电，开盖即亮。
```

### 使用限制

- 合盖可用，但系统继续运行（发热/耗电），别长时间合盖收纳
- 不要主动关屏（`pmset displaysleepnow` / 设置里的"关闭显示器"）→ 会黑
- 长时间收纳先关机；万一黑屏长按电源键

---

## 目录内容

| 路径 | 说明 |
| --- | --- |
| `EFI/` | 完整可用 EFI（源自 U 盘 ESP） |
| [`../power-policy/`](../power-policy/) | 电源守护脚本 + LaunchDaemon + README（重装后手动安装） |
| `README.md` | 本文件 |
| [`../checksums.txt`](../checksums.txt) | `EFI/` 内全部文件的 SHA-256 |

## 历史备份

| 备份 | 说明 |
| --- | --- |
| ~~EFI-Tahoe26.7.1-触摸板OK-20261104-0018~~ | 已删；触摸板可用、蓝牙未修 |
| ~~EFI-Tahoe26.7.1-全功能-20261104-0040~~ | 已删；蓝牙可用、无合盖结论 |
| `EFI-26.7.1-加速可用-20261101`（旧机器） | 显卡加速刚打通 |
| `/Volumes/EFI/config.plist.bak-20261103-072537` | 本轮改动前的 config |
| `/Volumes/EFI/kexts-backup-20261104-003238` | 官方 2.4.0 蓝牙 kext |

---

## 附加（2026-11-04 23:30~23:59）：外接显示实测不可用

### 板载 HDMI（DDI 1）

```text
[IGFB][ERROR][AUX] ddi = 1 Time out: 0x5d40023f（每 4ms 重试，循环）
sinkCount = 0；sinkCountChanged = 0
```

拔掉 HDMI 线后日志照旧刷、HPD 0/1 抖动 → 与线/显示器无关，DDI 1 的 AUX 驱动层未起来。

### USB-C → HDMI 转接头（DDI 3）热插拔

```text
ddi 3 isHPDLow = 0 sinkCount = 1 sinkCountChanged = 1
AGDP VendorEventHandler Port: 4 Event:Insert
```

之后只有每 30 秒一次的 `BRINGUP` 重试，不生成 `display0`，无画面。

### USB-C 冷启动（插着转接头开机）

全程没有出现过 `ddi 3` / `sinkCount = 1` → 开机时识别不到。

### 已排除

HDMI 线、显示器、接口（换线 / 换口 / 换显示器都试过，同一套设备在别的电脑正常）。

### 尝试过且无效的 boot-args（已全部回滚）

| 参数 | 作用 |
| --- | --- |
| `-nopsr` | 关 PSR |
| `-noDC9` | 禁止显示引擎进 DC9 |
| `-noAUXDelay` | 去掉 AUX 延迟 |

### 驱动自身未实现的部分（日志原文）

```text
[IGFB][WARN][BRINGUP] Bringup TODO: implement link rate determination from HW values
[IGFB][WARN][BRINGUP] Bringup TODO: implement drive strength determination from HW values
```

WEX changelog 中 Tiger Lake 的外部输出只写了 *USB-C DisplayPort Alt Mode output*；
README 里的 "HDMI" 来自其他测试机型（那些机型 HDMI 直连 DDI）。

**结论：外接显示器在这台机器上不可用。需要多屏只能用其它设备。**
