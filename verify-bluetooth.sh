#!/bin/bash
echo "===== 1. kext 版本 ====="
for k in IntelBluetoothFirmware IntelBTPatcher BlueToolFixup; do
  p="/Volumes/EFI/EFI/OC/Kexts/$k.kext/Contents/Info.plist"
  [ -f "$p" ] && printf "%-26s v%s\n" "$k" "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$p")"
done

echo
echo "===== 2. 已载入 ====="
kextstat | grep -iE "IntelBluetooth|IntelBT|BlueTool"

echo
echo "===== 3. Bluetooth 控制器状态 ====="
system_profiler SPBluetoothDataType 2>/dev/null | head -14

echo
echo "===== 4. NVRAM 变量 ====="
nvram -p 2>/dev/null | grep -i bluetooth

echo
echo "===== 5. bluetoothd 是否还在崩 ====="
echo "崩溃报告数量（本次开机后）: $(ls -1 ~/Library/Logs/DiagnosticReports 2>/dev/null | grep -c bluetoothd)"
echo "进程: $(pgrep -x bluetoothd | tr '\n' ' ')"

echo
echo "===== 6. Intel 固件日志 ====="
log show --last boot --style compact 2>/dev/null | grep -iE "IntelFirmware|IntelBluetooth" | tail -20
