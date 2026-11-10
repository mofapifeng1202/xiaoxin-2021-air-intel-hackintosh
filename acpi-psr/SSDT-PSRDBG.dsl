/*
 * SSDT-PSRDBG —— AC 适配器 _PSR 去抖
 *
 * 背景：
 *   本机 EC 的查询方法 _Q37 会在电源状态变化时执行：
 *       Notify (ACAD, 0x80) -> Sleep (1000) -> Notify (BAT1, 0x80) -> PWRS = ADPT
 *   macOS 的 SMCBatteryManager 收到 ACAD 通知后重新求值 _PSR，而 _PSR 只是读
 *   EC 的 ADPT 位。EC 正在改写状态字节的瞬间，ADPT 可能被读成 0，powerd 就把
 *   电源判定切到"电池"，1 秒后（_Q37 的 Sleep 结束、BAT1 通知到达）又切回 AC，
 *   PowerChime 于是再播一次"接入电源"音效。
 *   满电后 EC 不再充电、状态位频繁变化，因此该现象集中出现在充满电之后。
 *
 * 逻辑：
 *   1. ADPT = 1                 -> 返回 1（无延时）
 *   2. ADPT = 0 且上次已是 0    -> 返回 0（电池模式，不引入延时）
 *   3. ADPT = 0 但上次是 1      -> 等 2500ms 再读，仍为 0 才认定真的拔掉
 *
 * 配套改动（config.plist > ACPI > Patch，仅 DSDT，Count = 1）：
 *   Find:    5F 50 53 52  ("_PSR")
 *   Replace: 58 50 53 52  ("XPSR")
 *   把 DSDT 里 ACAD 原来的 _PSR 改名让位，由本 SSDT 提供新的 _PSR。
 */
DefinitionBlock ("", "SSDT", 2, "XIAOXN", "PSRDB", 0x00000001)
{
    External (_SB_.PC00.LPCB.EC0_, DeviceObj)
    External (_SB_.PC00.LPCB.EC0_.ADPT, FieldUnitObj)
    External (_SB_.PC00.LPCB.ACAD, DeviceObj)

    Scope (\_SB.PC00.LPCB.ACAD)
    {
        Name (PSRV, One)

        Method (_PSR, 0, NotSerialized)
        {
            If (\_SB.PC00.LPCB.EC0.ADPT)
            {
                PSRV = One
                Return (One)
            }

            If (!PSRV)
            {
                Return (Zero)
            }

            Sleep (0x09C4)

            If (\_SB.PC00.LPCB.EC0.ADPT)
            {
                PSRV = One
            }
            Else
            {
                PSRV = Zero
            }

            Return (PSRV)
        }
    }
}
