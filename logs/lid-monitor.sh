#!/bin/bash
LOG="/Users/wang/Desktop/xiaoxin-hackintosk/logs/lid-$(date +%H%M).log"
echo "=== 合盖测试开始 $(date '+%F %T') ===" > "$LOG"
for i in $(seq 1 300); do
  ts=$(date "+%T")
  wr=$(pmset -g assertions 2>/dev/null | grep -c IODisplayWrangler)
  fb=$(ioreg -rc AppleIntelFramebuffer -l -w0 2>/dev/null | grep -o '"CurrentPowerState"=[0-9]*' | head -1)
  ack=$(ioreg -rc AppleACPIPlatformExpert -l -w0 2>/dev/null | grep -c Clamshell)
  echo "$ts wrangler=$wr $fb clamshellRefs=$ack" >> "$LOG"
  sleep 2
done
