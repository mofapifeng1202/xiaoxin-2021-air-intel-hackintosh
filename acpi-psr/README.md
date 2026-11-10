# SSDT-PSRDBG：AC 适配器 `_PSR` 去抖

解决「满电后系统反复以为电源被拔插、不停播放充电音效」的问题。

## 现象

- 电量 100% 后，每隔几秒到几分钟响一次"接入电源"音效，状态栏电源图标闪一下；
- 但 `ioreg` 里 `ExternalConnected` 始终是 `Yes`，电池容量/电压没有变化；
- 抖动瞬间 `Amperage` 会出现 27248 mA、13088 mA 这类物理上不可能的数值
  → EC 数据"撕裂读"；
- Windows 下长期使用没有这个现象。

## 根因

DSDT 中 EC 的查询方法 `_Q37`：

```asl
Method (_Q37, 0, NotSerialized)
{
    Debug = "=====PROJECT_QUERY_37====="
    Notify (ACAD, 0x80)     // 电源适配器状态变化
    Sleep (0x03E8)          // 1 秒
    Notify (BAT1, 0x80)
    PWRS = ADPT
}
```

`SMCBatteryManager` 注册了 ACAD 通知，收到后重新求值：

```asl
Method (_PSR, 0, NotSerialized) { Local0 = ^^EC0.ADPT; Return (Local0) }
```

`ADPT` 是 EC 状态字节里的一位（与 `PBOV`/`ECRD`/`PWAK` 等共享同一字节）。
满电后 EC 频繁改写该字节，瞬时读到 `ADPT = 0` → `powerd` 判定切到电池；
1 秒后（`_Q37` 的 Sleep 结束、BAT1 通知到达）又读回 1 → 播放音效。

## 方案

1. **ACPI Patch（DSDT，Count = 1）**：把 DSDT 的 `_PSR` 改名让位

   ```text
   Find:    5F 50 53 52   ("_PSR")
   Replace: 58 50 53 52   ("XPSR")
   ```

2. **`SSDT-PSRDBG.aml`**：在 `\_SB.PC00.LPCB.ACAD` 下提供新的 `_PSR`

   ```asl
   ADPT = 1                -> 返回 1（无延时）
   ADPT = 0 且上次已是 0   -> 返回 0（电池模式，无延时）
   ADPT = 0 但上次是 1     -> 等 2500ms 再读，仍为 0 才返回 0
   ```

代价：真实拔掉电源后，状态栏约 2.5 秒才切到电池；插回是立即的。
电池模式下完全不会引入延时。

## 编译

需要 ACPICA 的 `iasl`（Homebrew `acpica` 或自行编译）：

```bash
iasl -p SSDT-PSRDBG.aml SSDT-PSRDBG.dsl
```

编译产物只有 237 字节，SHA-256：

```text
fabc6d67b409be8ab21ec9e727bc43145a582f68403e8fd9f1a0c28660e49691
```

## 部署

1. 把 `SSDT-PSRDBG.aml` 放进 `EFI/OC/ACPI/`；
2. `ACPI > Add` 增加一条 `SSDT-PSRDBG.aml`（Enabled = true）；
3. `ACPI > Patch` 增加上面的 `_PSR → XPSR` 重命名（TableSignature = DSDT，Count = 1）；
4. 重启。

## 验证

```bash
# 1. 看 OC 启动日志里是否加载了这张表（OEM Table ID = PSRDB）
grep -i "PSRDB" /Volumes/EFI/opencore-*.txt

# 2. 正常插着电源时应为 AC
pmset -g batt | head -1

# 3. 统计自动响铃（应当为 0）
pmset -g log | grep "chimeOnAttach" | grep Created | tail

# 4. 拔掉电源，观察状态栏约 2.5 秒后切到电池
```

## 回滚

把 `ACPI > Patch` 里 `ACAD _PSR to XPSR` 的 `Enabled` 改为 `false`
（或删除该条目），重启即可。`SSDT-PSRDBG.aml` 留着也不会生效。
