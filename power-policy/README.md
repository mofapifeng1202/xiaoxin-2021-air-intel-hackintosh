# 小新 Air 14ITL 黑苹果电源守护

> 防止合盖睡眠 → 唤醒黑屏（WEX 上游缺陷的规避方案）

## 背景

WEX 0.6.1 在 Tiger Lake 上「显示休眠唤醒」路径未实现：

```text
屏幕一关再唤醒 = AUX 超时 + link training 失败 + FB0 不使能 = 永久黑屏
```

必须让 macOS 完全不进入任何睡眠，合盖时由 EC 硬件关屏（这条路径是好的）。

## 关键坑

`sudo pmset -a disablesleep 1` 虽然立即生效，但 **每次开机 `powerd` 初始化时
都会把 `SleepDisabled` 清回 0**（plist 也写回 `false`）。一次性脚本追不上。

所以改成常驻循环守护：**每 2 秒检查，不是 `1` 就立刻改回来**。

## 文件

| 路径 | 说明 |
| --- | --- |
| `/usr/local/bin/xiaoxin-power-policy.sh` | 守护脚本 |
| `/Library/LaunchDaemons/local.xiaoxin.powerpolicy.plist` | LaunchDaemon |
| `/var/log/xiaoxin-powerpolicy.log` | stderr 日志 |

## 安装（重装系统后需要重新做）

```bash
sudo cp xiaoxin-power-policy.sh /usr/local/bin/
sudo chmod 755 /usr/local/bin/xiaoxin-power-policy.sh
sudo chown root:wheel /usr/local/bin/xiaoxin-power-policy.sh
sudo xattr -c /usr/local/bin/xiaoxin-power-policy.sh

sudo cp local.xiaoxin.powerpolicy.plist /Library/LaunchDaemons/
sudo chown root:wheel /Library/LaunchDaemons/local.xiaoxin.powerpolicy.plist
sudo chmod 644 /Library/LaunchDaemons/local.xiaoxin.powerpolicy.plist
sudo xattr -c /Library/LaunchDaemons/local.xiaoxin.powerpolicy.plist

sudo launchctl load -w /Library/LaunchDaemons/local.xiaoxin.powerpolicy.plist
```

> **注意**：新版 `launchctl bootstrap system ...` 在这台机器上报
> `Bootstrap failed: 5: Input/output error`，用旧式 `load -w` 正常。

## 验证

```bash
pmset -g | grep SleepDisabled          # 应为 1
launchctl list | grep xiaoxin          # 应有 PID

sudo pmset -a disablesleep 0           # 手动破坏
sleep 4
pmset -g | grep SleepDisabled          # 应自动回到 1
```

## 策略内容

```text
sleep 0  displaysleep 0  disksleep 0
hibernatemode 0  standby 0  autopoweroff 0  powernap 0
disablesleep 1     ← 关键
```

## 限制

- **不能主动关屏**：`pmset displaysleepnow` / 系统设置「关闭显示器」= 唤醒黑屏
- **合盖可用**，但系统仍在运行（发热/耗电，别长时间合盖塞包里）
- 长时间收纳请先关机
