#!/bin/bash
# 记录背光/显示状态，用于诊断唤醒黑屏
LOG="/Users/wang/Desktop/wake-diag-$(date +%H%M).log"
echo "=== 监控开始 $(date '+%F %T') ===" > "$LOG"
last=""
while true; do
  ts=$(date "+%T")
  params=$(ioreg -rc AppleBacklightDisplay -l -w0 2>/dev/null \
    | grep -o '"IODisplayParameters" = {.*}' | head -1 \
    | grep -oE '"(bklt|brightness|linear-brightness)"=\{[^}]*"value"=[0-9]+\}')
  if [ "$params" != "$last" ]; then
    echo "$ts  $params" >> "$LOG"
    last="$params"
  fi
  sleep 1
done
