#!/bin/bash
echo "===== 1. Voodoo kext 载入 ====="
kextstat | grep -iE "VoodooI2C|VoodooGPIO|VoodooInput" || echo "(无)"

echo
echo "===== 2. 设备节点 & 属性 ====="
ioreg -rn VoodooI2CDeviceNub -l 2>/dev/null | grep -E '"name"|"compatible"|"i2cAddress"|"sclHz"|"gpioPin"|"gpioIRQ"|IOClass' | head -20

echo
echo "===== 3. 是否有 HID 设备 ====="
ioreg -c VoodooI2CHIDDevice -l 2>/dev/null | head -5
echo "--- IOHIDDevice（触摸板相关）---"
ioreg -c IOHIDDevice -l 2>/dev/null | grep -iE '"(Product|Transport|VendorID|ProductID)"' | head -20

echo
echo "===== 4. 本次启动 Voodoo 日志 ====="
log show --last boot --style compact 2>/dev/null | grep -iE "voodooi2c|voodoo gpio|voodooinput" | tail -50

echo
echo "===== 5. 按键/触摸设备列表 ====="
ioreg -c AppleMultitouchDevice -l 2>/dev/null | grep -c . 
