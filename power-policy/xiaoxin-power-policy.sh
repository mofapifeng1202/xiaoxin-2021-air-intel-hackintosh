#!/bin/bash
# 小新 Air 14ITL 黑苹果电源策略守护
# 背景：SleepDisabled 每次开机（以及电源切换时）会被 powerd 清回 0，
#       一旦为 0 合盖就会真的睡眠 → 唤醒黑屏（WEX 上游缺陷）。
# 做法：常驻循环，发现不是 1 就立刻改回来（每 2 秒检查一次）。
while true; do
    if [ "$(/usr/bin/pmset -g | /usr/bin/awk '/SleepDisabled/{print $2}')" != "1" ]; then
        /usr/bin/pmset -a sleep 0 displaysleep 0 disksleep 0 \
            hibernatemode 0 standby 0 autopoweroff 0 powernap 0 \
            disablesleep 1
    fi
    /bin/sleep 2
done
