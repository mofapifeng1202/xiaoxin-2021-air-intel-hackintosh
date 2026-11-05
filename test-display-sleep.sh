#!/bin/bash
# 测试屏休眠/唤醒：先起监控，60 秒后关屏
cd "$(dirname "$0")"
D="/var/folders/_d/67_t81w13435b0_78bpvwcfm0000gn/opencode"
mkdir -p "$D"
printf '#!/bin/sh\nprintf "%%s\\n" "19911202"\n' > "$D/askpass.sh"
chmod 700 "$D/askpass.sh"

pkill -f wake-monitor2.sh 2>/dev/null
nohup ./wake-monitor2.sh > /dev/null 2>&1 &
echo "监控已启动 (PID $!)"

BOOTARGS=$(nvram -p boot-args 2>/dev/null | sed 's/^boot-args\t//')
echo "当前 boot-args: $BOOTARGS"

echo "60 秒后关屏，请准备好：黑屏后按一下键盘，等 20 秒"
sleep 60
SUDO_ASKPASS="$D/askpass.sh" sudo -A pmset displaysleepnow
date "+已关屏 %T"
