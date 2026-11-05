#!/bin/bash
# 唤醒黑屏诊断：等待屏休眠 -> 唤醒 -> 自动抓状态
LOG="/Users/wang/Desktop/wake-diag2-$(date +%H%M).log"
echo "=== 监控开始 $(date '+%F %T') ===" > "$LOG"

prev=""
slept=0
while true; do
  ts=$(date "+%T")
  wr=$(pmset -g assertions 2>/dev/null | grep -c "IODisplayWrangler")

  # 只在状态变化时记录
  if [ "$wr" != "$prev" ]; then
    bklt=$(ioreg -rc AppleBacklightDisplay -l -w0 2>/dev/null | grep -o '"bklt"={[^}]*}')
    echo "$ts  displayWrangler=$wr  $bklt" >> "$LOG"
    prev="$wr"
  fi

  if [ "$wr" = "0" ]; then
    slept=1
  fi

  # 从"屏休眠"回到"屏唤醒"的瞬间
  if [ "$wr" != "0" ] && [ "$slept" = "1" ]; then
    echo "$ts  ===== WAKE DETECTED ===== " >> "$LOG"
    slept=0
    sleep 5
    {
      echo "--- 背光参数 ---"
      ioreg -rc AppleBacklightDisplay -l -w0 2>/dev/null | grep -o '"IODisplayParameters" = {.*}'
      echo "--- 显示器列表 ---"
      system_profiler SPDisplaysDataType 2>/dev/null | head -25
      echo "--- framebuffer 在线状态 ---"
      ioreg -rc AppleIntelFramebuffer -l -w0 2>/dev/null | grep -E '"IOClass"|"Online"|"AAPL,boot-display"|"IOFBPowerState"|"CurrentPowerState"' | head -10
      echo "--- 唤醒后 IG 日志 ---"
      log show --last 30s --style compact 2>/dev/null | grep -E "IGFB|IOAccelDisplayPipe" | tail -40
      echo "======================"
    } >> "$LOG" 2>&1
  fi

  sleep 1
done
