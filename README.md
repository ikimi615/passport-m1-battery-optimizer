# 🔋 Passport M1 & Android 极限待机耗电优化器 + VPN/Wi-Fi 切换 IMS/VoLTE 修复工具

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Android%2010--15-brightgreen.svg" alt="Android Support" />
  <img src="https://img.shields.io/badge/Tested%20On-Passport%20M1%20(MT6877)-blue.svg" alt="Tested on Passport M1" />
  <img src="https://img.shields.io/badge/VoLTE%20%26%20IMS-VPN%20Handover%20Fixed-blueviolet.svg" alt="VPN Wi-Fi IMS Fix" />
  <img src="https://img.shields.io/badge/License-MIT-orange.svg" alt="License" />
  <img src="https://img.shields.io/badge/Mode-Root%20%7C%20No--Root%20(ADB%2FShizuku)-success.svg" alt="Execution Mode" />
</p>

一套经过实机长周期严苛验证的 **雷火 Passport M1（黑莓全键盘复刻机，MTK 天玑 900 / LineageOS 19.1）与通用 Android 10 ~ 15 极限待机省电、温控发热根治方案，以及「先连 VPN 再开 Wi-Fi 导致 IMS 错误 / VoLTE 断联」的源码级修复工具**。

---

## 📊 优化前后实测数据对比（实机 42 小时连续跟踪）

> 测试设备：雷火 Passport M1 (天玑 900, Android 12, 5090mAh 电池, 联通 4G 移动网络 + Wi-Fi 混合日常使用)

| 监控指标 | 优化前 (原厂状态) | 优化后 (42h 连续在网实测) | 改善幅度 |
| :--- | :--- | :--- | :--- |
| **综合平均掉电速率** | **2.5% ~ 3.5% / 小时** | **0.928% / 小时（42.0h 仅耗电 39%）** | ⏳ **续航提升近 3 倍** |
| **息屏掉电间隔** | **22 ~ 28 分钟掉 1%** | **连续 20 个 1% 阶梯均达 60 ~ 66 分钟** | 📈 **极端稳定 1 小时 1%** |
| **夜间 8h 待机耗电** | 约 **20% ~ 25%** | **仅耗电约 7.4%（纯静置低至 3%）** | 📉 **待机电量暴降** |
| **连续在网续航推算** | 约 18 ~ 22 小时 | **满电综合续航可达 105+ 小时（超 4 天）** | 🚀 **告别续航焦虑** |
| **CPU 深度睡眠比率** | 频繁被传感器和扫频唤醒 (<50%) | **Deep Doze 连续深睡达 95%+** | 💤 **真正进入 Deep Sleep** |
| **机身温度** | 口袋常年温热（35°C ~ 40°C） | **26°C ~ 28°C（室温微凉状态）** | ❄️ **发热彻底解决** |

---

## 🛡️ 专项修复：先连 VPN 再开 Wi-Fi 导致 IMS 错误 / VoLTE 失效

### 1. 故障现象
在 Passport M1（及部分联发科 Android 12+ 机型）上使用 `FlClash` (`com.oixcloud.clash` / `com.follow.clash`) 等 VPN 时：
- **先连 Wi-Fi ➔ 再打开 VPN**：IMS 与 VoLTE 正常；
- **先在移动数据下打开 VPN ➔ 再打开并连接 Wi-Fi**：立刻出现 **IMS 错误，VoLTE 彻底失效无法拨打电话**。

### 2. 三大底层根因剖析（基于 `logcat -b crash/radio/system` 与路由表实测）

1. **联发科 `com.mediatek.ims` 进程类型转换崩溃 (`ClassCastException`)**  
   ```text
   FATAL EXCEPTION: ConnectivityThread
   Process: com.mediatek.ims (UID: 1001)
   java.lang.ClassCastException: android.net.VpnTransportInfo cannot be cast to android.net.wifi.WifiInfo
       at com.mediatek.wfo.impl.WifiPdnHandler.isPrimaryWifi(WifiPdnHandler.java:2093)
       at com.mediatek.wfo.impl.WifiPdnHandler$3.onCapabilitiesChanged(WifiPdnHandler.java:1774)
   ```
   - `com.mediatek.ims`（`UID 1001`）中的 `WifiPdnHandler` 注册了监听 `TRANSPORT_WIFI` 的网络回调，但**未声明 `NET_CAPABILITY_NOT_VPN`**。
   - 当 VPN 未排除系统通信组件时，`tun0` 接管了 `Uids: <{0-99999}>`（包含 `UID 1001`）。此时再开启并连上 Wi-Fi，系统将 VPN 网络的底层传输更新为 `Transports: WIFI|VPN`，并将 `VpnTransportInfo` 推送给 `com.mediatek.ims`。
   - `WifiPdnHandler.isPrimaryWifi()` 将 `VpnTransportInfo` 强转为 `WifiInfo` 当场崩溃！连续崩溃 2 次后被系统 `ActivityManager` 惩罚性挂起 **30 分钟 (`1800000ms`)**，导致 IMS 服务彻底断联。

2. **`tun0` IPv6 黑洞路由劫持 `UID 1001`**  
   - 运营商（如中国联通）IMS 专网 (`ccmni0`) 采用纯 IPv6 承载 (`2408:8556:...`)；而 VPN (`tun0`) 默认下发 `::/0 unreachable` IPv6 黑洞路由并拦截 `uidrange 0-99999`，导致 Wi-Fi 切换触发无线策略重协商 (`+EIWLPL`) 时，`UID 1001` 探测包坠入 IPv6 黑洞。

3. **后台限制拦截 `VpnService` 切网 (`startForeground() not allowed`)**  
   - 若 VPN 客户端被设为 `RUN_ANY_IN_BACKGROUND ignore`，切到后台开启 Wi-Fi 时，`VpnService` 重建隧道会被 `ActivityManager` 拦截。

### 3. 一键根治方案 (`scripts/fix_vpn_wifi_ims.sh`)
本项目内置 [`scripts/fix_vpn_wifi_ims.sh`](./scripts/fix_vpn_wifi_ims.sh)（及 Windows 双击版 [`scripts/fix_vpn_wifi_ims_windows.bat`](./scripts/fix_vpn_wifi_ims_windows.bat)），一键完成：
- **解除 VPN 后台限制并加入 Doze 白名单**：自动放行 `RUN_ANY_IN_BACKGROUND`、`RUN_IN_BACKGROUND`、`START_FOREGROUND`；
- **自动向 `FlClash` 注入 `UID 1001` 分流绕过配置**：直接修改 `FlutterSharedPreferences.xml`（兼容内置存储与扩展格式化存储 `/mnt/expand/...`），将 `com.mediatek.ims`、`com.android.phone`、`com.mediatek.telephony` 等 `UID 1001` 组件加入 `rejectList`，使 `tun0` 路由范围变为 `Uids: <{0-1000, 1002-99999}>`，从根源上杜绝 `com.mediatek.ims` 收到 `VpnTransportInfo`；
- **立即唤醒挂起的 `MtkDynamicImsService`**：解除 30 分钟崩溃冻结，立即恢复 `ccmni0` IMS 专网与 VoLTE。

---

## 🔍 五大待机省电优化原理

1. **斩断运营商 2G/3G 退网搜网死循环与 5G SA 空载高功耗**  
   锁定最优 4G LTE 频段，消除基带 `rejectCause=18` 死循环与 5G SA 弱信号发热。
2. **极速深度休眠（持久化 `DeviceConfig` Doze）**  
   通过 `device_config put device_idle` 持久化写入系统数据库（重启不失效），息屏 **60 秒**进浅睡、**5 分钟**直奔 Deep Doze。
3. **关闭后台隐形高频定位扫描**  
   关闭系统默认开启的 `wifi_scan_always_enabled`、`ble_scan_always_enabled` 与 `adaptive_connectivity_enabled`。
4. **AppOps 级后台流氓常驻锁死（智能豁免 VPN）**  
   针对小红书、微博、推特、淘宝、京东、高德、墨迹天气等后台偷跑大户施加 `RUN_ANY_IN_BACKGROUND ignore`，同时**自动豁免 `FlClash` 等 VPN 核心工具**。
5. **内核唤醒锁归零（Zero Suspend Blockers）**  
   清理阻碍 CPU 深度休眠的无效唤醒锁，让 PMIC 顺畅拉低供电电压。

---

## 🚀 极速上手使用指南

### 方式 1：Windows 电脑一键运行

1. 手机连上电脑，开启【USB 调试】；
2. 下载本项目 Release 或克隆仓库：
   - 双击 **`scripts/optimize_windows.bat`**：执行全套极限省电优化；
   - 双击 **`scripts/fix_vpn_wifi_ims_windows.bat`**：一键修复 VPN 与 Wi-Fi 切换导致的 IMS/VoLTE 错误。

### 方式 2：macOS / Linux 电脑一键运行

```bash
# 1. 克隆项目
git clone https://github.com/ikimi615/passport-m1-battery-optimizer.git
cd passport-m1-battery-optimizer

# 2. 执行极限待机省电优化
adb push scripts/optimize.sh /data/local/tmp/
adb shell "sh /data/local/tmp/optimize.sh"

# 3. 执行 VPN <-> Wi-Fi 切换 IMS/VoLTE 崩溃根治修复
adb push scripts/fix_vpn_wifi_ims.sh /data/local/tmp/
adb shell "sh /data/local/tmp/fix_vpn_wifi_ims.sh"
```

### 方式 3：手机端本地直接运行（MT 管理器 / Termux / Shizuku）

* **若手机已 Root**：在 MT 管理器中点击 `scripts/optimize.sh` 或 `scripts/fix_vpn_wifi_ims.sh`，勾选【以 root 身份运行】。
* **若手机未 Root**：通过 **Shizuku** 终端执行脚本，并在 `FlClash` 内开启【访问控制 / 分应用代理 -> 绕过模式】，取消隐藏系统应用，勾选 `com.mediatek.ims` 与 `电话 (com.android.phone)`。

---

## 🛠️ 工具集说明

* [`scripts/optimize.sh`](./scripts/optimize.sh)：一键综合待机省电优化脚本（已内置 VPN 后台豁免保护）。
* [`scripts/optimize_windows.bat`](./scripts/optimize_windows.bat)：Windows 一键省电优化批处理。
* [`scripts/fix_vpn_wifi_ims.sh`](./scripts/fix_vpn_wifi_ims.sh)：**VPN 与 Wi-Fi 切换导致 IMS/VoLTE 错误专项修复脚本**。
* [`scripts/fix_vpn_wifi_ims_windows.bat`](./scripts/fix_vpn_wifi_ims_windows.bat)：Windows 一键修复 VPN/Wi-Fi IMS 错误批处理。
* [`scripts/diagnose.sh`](./scripts/diagnose.sh)：电量诊断工具，一键检测深睡百分比、机身温度与耗电前五大应用。
* [`scripts/restore.sh`](./scripts/restore.sh)：一键安全回滚脚本，恢复 Android 出厂默认电量与后台设置。

---

## 📄 开源许可证

本项目基于 [MIT License](./LICENSE) 协议开源。欢迎 Star、Fork 与改进！
