---
name: android-battery-optimizer
description: >-
  Optimizes Android standby battery drain, fixes carrier 2G/3G shutdown search loops,
  enables fast Deep Doze sleep, and suppresses rogue background apps. Use when an Android
  phone suffers from severe overnight battery drain, pocket heating, or poor standby time.
---

# Android 极限待机耗电优化器 (Android Battery & Deep Sleep Optimizer)

本 Skill 提供了一套经过实机长时验证的 **Android 待机极限省电与发热根治方案**。针对定制机、二手机、复刻机（如雷火 Passport M1、黑莓移植机）、以及各类搭载 Android 10 ~ 15（LineageOS、AOSP、ColorOS、MIUI 等）的设备，解决息屏严重耗电、发热、掉电快的通病。

实测效果：**待机掉电速度由每 25 分钟掉 1% 优化至每 2 小时 17 分钟掉 1%（待机耗电降低近 6 倍），8 小时整夜耗电从 25% 降至 2%~3%，CPU 深度睡眠比率达 97.5% 以上。**

---

## 📌 典型耗电症状与排查

当手机出现以下一种或多种情况时，即可直接使用本 Skill：
1. **息屏严重掉电**：晚上睡觉前 100%，早上起来只剩 70% ~ 80%（夜间掉电 > 15%）。
2. **锁屏发热**：手机放在口袋或桌面上，即使未点亮屏幕，机身也一直温热（电池温度 > 34°C）。
3. **运营商退网死循环**：在国内联通/电信 2G/3G 退网后，基带日志不断循环 `rejectCause=18`，频繁扫频漫游，射频发射管全天候高功率运行。
4. **流氓后台常驻**：小红书、电商软件、应用市场常驻后台，持续持有 WakeLock 或 50Hz 传感器唤醒 CPU。
5. **休眠延迟过长**：原生 Android 默认息屏后需要 30 ~ 60 分钟才尝试进入 Doze，稍有晃动即退出休眠。

---

## 🛠️ 一键自动化脚本与使用方法

本 Skill 包含 3 个立即可执行的脚本，存放在 `scripts/` 目录中：

| 脚本文件 | 功能描述 |
| :--- | :--- |
| [`scripts/optimize.sh`](./scripts/optimize.sh) | **一键综合优化脚本**：配置蜂窝网络模式、注入极速休眠参数、关闭隐形扫描、压制流氓后台 |
| [`scripts/diagnose.sh`](./scripts/diagnose.sh) | **电量健康诊断工具**：计算深度休眠率、查看当前机身温度、检测是否有唤醒锁阻碍挂起 |
| [`scripts/restore.sh`](./scripts/restore.sh) | **一键还原脚本**：若需恢复原厂设置，一键恢复所有参数至系统默认值 |

### 方法一：通过电脑端 ADB 一键运行（推荐）

手机开启 USB 调试并授予 Root 权限后，在电脑终端执行：

```bash
# 1. 运行一键优化
adb push scripts/optimize.sh /data/local/tmp/
adb shell "su -c 'sh /data/local/tmp/optimize.sh'"

# 2. 拔掉数据线，息屏静置一段时间后，运行诊断查看优化成效
adb push scripts/diagnose.sh /data/local/tmp/
adb shell "su -c 'sh /data/local/tmp/diagnose.sh'"
```

### 方法二：在手机端本地运行（Termux / MT 管理器）

将 `scripts/optimize.sh` 拷贝至手机存储，在 Termux 或 MT 管理器的终端中直接执行：

```bash
su
sh /sdcard/optimize.sh
```

---

## 🔬 五大核心优化原理详解

### 1. 解决运营商 2G/3G 退网搜网死循环 (Radio CS OOS Loop)
- **原因**：国内 2G/3G 逐步关停，当手机仍设置支持 2G/3G 回落（CSFB）时，基带会陷入搜不到电路域信号不断循环发包注册的死循环。
- **方案**：将首选网络锁定至纯数据/LTE 优选模式（Mode 9），关闭“始终保持移动数据开启”（当 Wi-Fi 连接时切断移动蜂窝高功耗待机链路）。

### 2. 注入极速深度休眠参数 (Aggressive Doze & Deep Idle)
- **参数配置**：
  ```bash
  dumpsys deviceidle set-param-string \
    inactive_to=60000,\
    sensing_to=0,\
    locating_to=0,\
    motion_inactive_to=0,\
    idle_after_inactive_to=0,\
    idle_pending_to=60000,\
    quick_doze_delay_to=30000
  ```
- **效果**：息屏后仅需 **60 秒** 即进入浅度睡眠，**5 分钟** 内直接挂起 CPU 进入 Deep Doze，忽略微小的日常晃动误唤醒。

### 3. 切断隐形后台扫描与广播风暴
- 关闭 Android 默认勾选的“即使 Wi-Fi / 蓝牙关闭，依然允许后台高频扫描附近热点与 Beacon”的隐形耗电漏洞：
  ```bash
  settings put global wifi_scan_always_enabled 0
  settings put global ble_scan_always_enabled 0
  settings put global adaptive_connectivity_enabled 0
  ```

### 4. AppOps 级后台流氓常驻压制 (Background Guard)
- 通过系统权限级别拦截小红书、短视频、天气、第三方应用商店等常见耗电应用的后台运行（`RUN_ANY_IN_BACKGROUND ignore`），不影响前台正常打开使用，但在退到后台时彻底切断其 CPU 消耗。

### 5. 清理唤醒锁阻碍 (Zero Suspend Blockers)
- 确保系统内核 `Suspend Blockers: ref count=0`，使联发科 / 高通芯片的 SPM（System Power Manager）能够顺畅拉低供电轨电压。

---

## ✅ 验证优化成效清单

优化完成后，建议执行以下步骤进行验收：

1. **查看机身温度**：
   ```bash
   adb shell "dumpsys battery | grep temperature"
   ```
   *正常指标*：息屏静置 30 分钟后，机身温度应降至 **26°C ~ 29°C**（室内常温）。
2. **查看深度休眠百分比**：
   ```bash
   adb shell "su -c 'dumpsys batterystats --charged | grep -E \"Total run time:|Discharge:\"'"
   ```
   *正常指标*：`realtime` 与 `uptime` 差异明显，`uptime`（CPU唤醒时间）应少于总时间的 **5%**（即深睡率 > 95%）。
3. **查看掉电速率**：
   ```bash
   adb shell "dumpsys batterystats --daily | grep -A 5 \"Current daily discharge step durations\""
   ```
   *正常指标*：每掉 1% 电量所需的待机时间应在 **1.5 小时 ~ 2.5 小时以上**。

---

## 🔄 恢复与回滚

若由于特殊网络环境需要恢复原厂所有电量与扫描行为，只需执行：

```bash
adb shell "su -c 'sh /data/local/tmp/restore.sh'"
```
