---
name: android-battery-optimizer
description: >-
  Optimizes Android standby battery drain, fixes carrier 2G/3G shutdown search loops,
  enables fast Deep Doze sleep, suppresses rogue background apps, and fixes MTK IMS/VoLTE
  crashes when switching between VPN (FlClash) and Wi-Fi. Use when an Android phone suffers
  from severe overnight battery drain, pocket heating, or VPN/Wi-Fi handover IMS errors.
---

# Android 极限待机耗电优化器 & VPN/Wi-Fi 切换 IMS 修复套件

本 Skill 提供了一套经过实机长时验证的 **Android 待机极限省电与发热根治方案**，以及针对联发科（MTK）设备 **「先连 VPN 再开 Wi-Fi 导致 `com.mediatek.ims` 崩溃与 VoLTE 失效」的一键修复方案**。

实测效果：
- **待机续航**：在雷火 Passport M1（天玑 900 / 5090mAh）连续 **42 小时** 移动数据 + Wi-Fi 混合实测中，平均耗电仅 **0.928%/小时**（连续 20 个 1% 放电阶梯均稳定在 **60 ~ 66 分钟/1%**）。
- **VPN/Wi-Fi 切网 IMS 稳定性**：彻底消除 `WifiPdnHandler` 的 `ClassCastException: android.net.VpnTransportInfo cannot be cast to android.net.wifi.WifiInfo` 崩溃与 `tun0` IPv6 黑洞路由劫持，实现任意顺序开关 VPN 与 Wi-Fi 均 0 崩溃、VoLTE 全程在线。

---

## 🛠️ 脚本清单与功能

| 脚本文件 | 功能描述 |
| :--- | :--- |
| [`scripts/optimize.sh`](./scripts/optimize.sh) | **一键综合省电优化**：配置 4G 节能频段、持久化 `DeviceConfig` 极速 Doze、关闭隐形扫描、压制流氓后台并豁免 VPN 核心服务 |
| [`scripts/fix_vpn_wifi_ims.sh`](./scripts/fix_vpn_wifi_ims.sh) | **VPN/Wi-Fi 切换 IMS 崩溃专项修复**：解除 VPN 后台受限、自动配置 `FlClash` 排除 `UID 1001` (`com.mediatek.ims` / `com.android.phone`)、唤醒被挂起的 `MtkDynamicImsService` |
| [`scripts/diagnose.sh`](./scripts/diagnose.sh) | **电量健康诊断工具**：计算深度休眠率、查看机身温度与唤醒锁状态 |
| [`scripts/restore.sh`](./scripts/restore.sh) | **一键还原脚本**：恢复所有省电参数与应用后台权限至系统默认值 |

---

## 🔬 VPN <-> Wi-Fi 切换导致 IMS/VoLTE 错误的根因与修复机制

### 1. 根因链条
1. **`com.mediatek.ims` 类型转换崩溃 (`WifiPdnHandler.java:2093`)**：
   `WifiPdnHandler` 注册了不含 `NET_CAPABILITY_NOT_VPN` 的 `TRANSPORT_WIFI` 回调。若先开启 VPN 且未排除 `UID 1001`，再连接 Wi-Fi 时，VPN 网络更新为 `Transports: WIFI|VPN` 并携带 `VpnTransportInfo` 回调给 `com.mediatek.ims`，导致 `(WifiInfo) nc.getTransportInfo()` 抛出 `ClassCastException` 崩溃，连续崩溃两次后被系统挂起 30 分钟 (`1800000ms`)。
2. **IPv6 黑洞路由劫持**：
   运营商 IMS 专网 (`ccmni0`) 为纯 IPv6，而 `tun0` 默认对 `uidrange 0-99999` 注入 `::/0 unreachable`。
3. **`VpnService` 后台受限**：
   `RUN_ANY_IN_BACKGROUND ignore` 导致 VPN 在后台切换底层网络时被拦截 (`Service.startForeground() not allowed`)。

### 2. 一键修复命令
```bash
adb push scripts/fix_vpn_wifi_ims.sh /data/local/tmp/
adb shell "sh /data/local/tmp/fix_vpn_wifi_ims.sh"
```
执行后验证指标：
- `dumpsys connectivity` 中 VPN (`tun0`) 的 `Uids` 显示为 `<{0-1000, 1002-99999}>`（已排除 `UID 1001`）；
- `ip -6 rule` 中 `lookup tun0` 拆分为 `uidrange 0-1000` 与 `uidrange 1002-99999`；
- `com.mediatek.ims` 进程稳态运行，`ccmni0` (`MOBILE[LTE] extra: ims`) 保持 `CONNECTED & VALIDATED`。
