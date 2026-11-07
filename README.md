# 🔋 Passport M1 & Android 极限待机耗电优化器

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Android%2010--15-brightgreen.svg" alt="Android Support" />
  <img src="https://img.shields.io/badge/Tested%20On-Passport%20M1%20(MT6877)-blue.svg" alt="Tested on Passport M1" />
  <img src="https://img.shields.io/badge/License-MIT-orange.svg" alt="License" />
  <img src="https://img.shields.io/badge/Mode-Root%20%7C%20No--Root%20(ADB%2FShizuku)-success.svg" alt="Execution Mode" />
</p>

一套经过实机数日严苛验证的 **Android 极限待机省电、温控发热根治方案**。

针对**雷火 Passport M1（黑莓全键盘复刻机，MTK 天玑 900 / LineageOS 固件）**、各类定制 ROM、二手机及通用 Android 10 ~ 15 设备，彻底解决息屏掉电快、口袋发热、运营商退网搜网死循环等通病。

---

## 📊 优化前后实测数据对比（实机 28+ 小时跟踪）

> 测试设备：雷火 Passport M1 (天玑 900, Android 12, 5090mAh 电池, 联通 4G 移动网络全天开启)

| 监控指标 | 优化前 (原厂状态) | 优化后 (开启移动网络实测) | 改善幅度 |
| :--- | :--- | :--- | :--- |
| **息屏掉电间隔** | **22 ~ 28 分钟掉 1%** | **54 分钟 ~ 1 小时 09 分钟掉 1%** | ⏳ **放电速度减慢近 3 倍** |
| **夜间 8h 待机耗电** | 约 **20% ~ 25%** | **仅耗电约 8%（静置 Wi-Fi 仅 3%）** | 📉 **待机电量暴降** |
| **连续在网待机时长** | 约 18 ~ 22 小时 | **已连续运行 28.5 小时，剩余 43% 电量** | 🚀 **单次满电待机可达 50 小时（超2天）** |
| **CPU 深度睡眠比率** | 频繁被传感器和扫频唤醒 (<50%) | **Deep Doze 连续深睡达 4 ~ 6 小时** | 💤 **真正进入 Deep Sleep** |
| **蜂窝网络射频耗电** | 每小时持续高发射功耗 | **16 小时移动网络仅耗电 4.09 mAh** | 📡 **基带死循环彻底消除** |
| **机身温度** | 口袋常年温热（35°C ~ 40°C） | **27°C ~ 28°C（室温微凉状态）** | ❄️ **发热彻底解决** |

---

## 🔍 五大核心优化原理

1. **斩断运营商 2G/3G 退网搜网死循环**  
   国内运营商逐步关停 2G/3G，部分定制 ROM 基带仍在后台疯狂尝试 CS 域回落（循环报错 `rejectCause=18`）。脚本锁定最优 LTE 优选模式（Mode 9），关闭无用的蜂窝高功耗常驻链路。
2. **极速深度休眠（Aggressive Doze & Deep Idle）**  
   原版 Android 息屏需要 30 ~ 60 分钟才迟钝地尝试休眠，且稍微晃动手机就会退出。本方案将参数缩短至**息屏 60 秒**进浅睡、**5 分钟**直奔 Deep Doze，忽略微小晃动误唤醒。
3. **关闭后台隐形高频定位扫描**  
   关闭系统默认开启的“即使 Wi-Fi / 蓝牙关闭，依然允许后台高频扫描附近热点与 Beacon”的偷跑漏洞。
4. **AppOps 级后台流氓常驻锁死**  
   针对小红书、电商软件、应用市场等后台高频发送心跳或占用 CPU 的流氓应用，施加 `RUN_ANY_IN_BACKGROUND ignore`，切断其退到后台时的 CPU 占用（完全不影响前台正常打开使用）。
5. **内核唤醒锁归零（Zero Suspend Blockers）**  
   清理阻碍 CPU 深度休眠的无效唤醒锁，让联发科 / 高通芯片的电源管理芯片（PMIC）顺畅拉低供电电压。

---

## 🚀 极速上手使用指南

本项目提供 **Root / 免 Root（ADB 或 Shizuku）双模式自动兼容**，任何人都能轻松使用：

### 方式 1：Windows 电脑一键免 Root 运行（最推荐）

1. 手机连上电脑，进入【设置 -> 开发者选项】开启【USB 调试】；
2. 下载本项目 Release 或克隆仓库；
3. 双击运行 **`scripts/optimize_windows.bat`**；
4. 几秒钟自动完成全套优化，提示完成后直接拔掉数据线即可！

### 方式 2：macOS / Linux 电脑一键运行

```bash
# 1. 克隆项目
git clone https://github.com/ikimi615/passport-m1-battery-optimizer.git
cd passport-m1-battery-optimizer

# 2. 推送并执行
adb push scripts/optimize.sh /data/local/tmp/
adb shell "sh /data/local/tmp/optimize.sh"
```

### 方式 3：手机端本地直接运行（无需电脑）

* **若手机已 Root**：  
  在 MT 管理器中点击 `scripts/optimize.sh`，勾选【以 root 身份运行】（或在 Termux 输入 `su` 后执行 `sh optimize.sh`）。
* **若手机未 Root**：  
  安装并激活 **Shizuku**，在 aShell 或 MT 管理器中以 Shizuku 环境执行 `optimize.sh`。

### 方式 4：作为 Antigravity / AI Agent Skill 导入

本项目原生包含符合规范的 [`SKILL.md`](./SKILL.md)，直接将整个目录放入你的智能编程助手 `.agents/skills/` 中即可自动识别并调用。

---

## 🛠️ 工具集说明

* **`scripts/optimize.sh`**：一键综合优化脚本（自动识别 Root / 非 Root Shell 权限）。
* **`scripts/optimize_windows.bat`**：Windows 一键双击批处理脚本。
* **`scripts/diagnose.sh`**：电量诊断工具，一键检测当前的深睡百分比、机身温度与耗电前五大应用。
* **`scripts/restore.sh`**：一键安全回滚脚本，随时恢复为 Android 出厂默认值。

---

## ❓ 常见问题 (FAQ)

**Q: 会影响前台正常玩游戏、刷微信吗？**  
A: 完全不会。优化只针对“息屏待机状态”与“后台偷跑行为”，屏幕点亮时手机处于满血性能状态，微信消息也能正常收取。

**Q: 执行之后需要重启手机吗？**  
A: 不需要，所有参数即刻生效。拔掉数据线、息屏静置即可开始享受极低待机功耗。

**Q: 想要恢复原厂设置怎么办？**  
A: 随时运行 `restore.sh`，所有参数与应用权限将立刻还原为出厂默认值。

---

## 📄 开源许可证

本项目基于 [MIT License](./LICENSE) 协议开源。欢迎 Star、Fork 与改进！
