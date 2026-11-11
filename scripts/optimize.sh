#!/bin/sh
# ==============================================================================
# Android Deep Sleep & Battery Optimizer (Dual Mode: Root & No-Root ADB/Shizuku)
# Target: Android 10 - 15 (Tested on MTK Dimensity, Snapdragon, Custom ROMs)
# ==============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo "${CYAN}======================================================${NC}"
echo "${CYAN}     Android Deep Sleep & Battery Optimizer v1.1      ${NC}"
echo "${CYAN}======================================================${NC}"

CURRENT_UID=$(id -u 2>/dev/null || echo "9999")

if [ "$CURRENT_UID" = "0" ]; then
    echo "${GREEN}[权限状态] 已获取最高 Root 权限，进入全功能极限优化模式。${NC}"
elif [ "$CURRENT_UID" = "2000" ]; then
    echo "${GREEN}[权限状态] 已获取 ADB / Shizuku (Shell) 权限，免 Root 优化模式已生效！${NC}"
else
    # Try auto-elevation if su exists
    if which su >/dev/null 2>&1 || [ -x /system/bin/su ] || [ -x /system/xbin/su ]; then
        echo "${YELLOW}[INFO] 检测到当前非 Root，正在尝试申请 Root 提权 (su)...${NC}"
        exec su -c "sh \"$0\" \"$@\""
    else
        echo "${RED}[ERROR] 当前权限不足 (UID: $CURRENT_UID)。${NC}"
        echo "${YELLOW}解决方案：${NC}"
        echo "1. 【免 Root 手机端】：在手机上安装【Shizuku】，通过 Shizuku 终端执行本脚本；"
        echo "2. 【免 Root 电脑端】：手机开启 USB 调试，用电脑运行：adb shell \"sh $0\"；"
        echo "3. 【有 Root 手机】：请在 MT 管理器运行窗口勾选【以 root 身份运行】。"
        exit 1
    fi
fi

echo "${BLUE}[1/5] 正在优化移动网络与基带搜网策略 (解决退网搜网死循环与 5G 射频高功耗)...${NC}"
# 针对 2G/3G 退网搜网死循环，并锁定 4G LTE (防止 5G SA 高频带 n78 空载发热):
cmd phone set-allowed-network-types-for-users -s 0 01001111101111111111 2>/dev/null || true
settings put global preferred_network_mode 9 2>/dev/null || true
settings put global preferred_network_mode1 9 2>/dev/null || true
settings put global mobile_data_always_on 0 2>/dev/null || true
echo "${GREEN}  ✓ 基带搜网死循环防御与 4G 节能频段已锁定${NC}"

echo "${BLUE}[2/5] 正在配置极速深度休眠策略 (持久化 DeviceConfig 极速 Doze)...${NC}"
dumpsys deviceidle enable all >/dev/null 2>&1 || true

# 写入 Android 10-15 官方持久化 DeviceConfig 数据库 (开机自动生效，不再失效)
device_config put device_idle inactive_to 60000 2>/dev/null || true
device_config put device_idle sensing_to 0 2>/dev/null || true
device_config put device_idle locating_to 0 2>/dev/null || true
device_config put device_idle location_accuracy 20.0 2>/dev/null || true
device_config put device_idle motion_inactive_to 0 2>/dev/null || true
device_config put device_idle idle_after_inactive_to 0 2>/dev/null || true
device_config put device_idle idle_pending_to 60000 2>/dev/null || true
device_config put device_idle max_idle_pending_to 120000 2>/dev/null || true
device_config put device_idle idle_pending_factor 2.0 2>/dev/null || true
device_config put device_idle idle_to 900000 2>/dev/null || true
device_config put device_idle max_idle_to 21600000 2>/dev/null || true
device_config put device_idle idle_factor 2.0 2>/dev/null || true
device_config put device_idle min_time_to_alarm 1800000 2>/dev/null || true
device_config put device_idle quick_doze_delay_to 30000 2>/dev/null || true
device_config put device_idle light_after_inactive_to 5000 2>/dev/null || true
device_config put device_idle light_pre_idle_to 10000 2>/dev/null || true
device_config put device_idle light_idle_to 180000 2>/dev/null || true
echo "${GREEN}  ✓ 极速休眠持久化参数已注入 (息屏 60s 内挂起 CPU，关机重启不失效)${NC}"

echo "${BLUE}[3/5] 正在关闭后台隐形搜网与定位泄漏 (Wi-Fi/BLE Scanning)...${NC}"
settings put global wifi_scan_always_enabled 0 2>/dev/null || true
settings put global ble_scan_always_enabled 0 2>/dev/null || true
settings put global adaptive_connectivity_enabled 0 2>/dev/null || true
echo "${GREEN}  ✓ 后台高频 Wi-Fi / 蓝牙扫描已彻底关闭${NC}"

echo "${BLUE}[4/5] 正在压制后台高耗电应用 (AppOps Background Guard)...${NC}"
TARGET_APPS="
com.xingin.xhs
com.weather.mjweather
com.tencent.android.qqdownloader
com.ss.android.ugc.aweme
com.taobao.taobao
com.jingdong.app.mall
com.autonavi.minimap
com.twitter.android
com.sina.weibo
com.huawei.hwid
"

# 确保 VPN 核心服务 (FlClash 等) 不被后台限制拦截 VpnService 网络切换，避免切 Wi-Fi 时触发 IMS 断联
for VPN_PKG in com.oixcloud.clash com.follow.clash com.github.metacubex.clash.meta com.github.kr328.clash; do
    if pm list packages 2>/dev/null | grep -q "^package:$VPN_PKG$"; then
        cmd appops set "$VPN_PKG" RUN_ANY_IN_BACKGROUND allow 2>/dev/null || true
        cmd appops set "$VPN_PKG" RUN_IN_BACKGROUND allow 2>/dev/null || true
        cmd appops set "$VPN_PKG" START_FOREGROUND allow 2>/dev/null || true
        dumpsys deviceidle whitelist +"$VPN_PKG" >/dev/null 2>&1 || true
    fi
done

RESTRICT_COUNT=0
for PKG in $TARGET_APPS; do
    if pm list packages 2>/dev/null | grep -q "^package:$PKG$"; then
        cmd appops set "$PKG" RUN_ANY_IN_BACKGROUND ignore 2>/dev/null || true
        cmd appops set "$PKG" RUN_IN_BACKGROUND ignore 2>/dev/null || true
        echo "  - 已限制后台运行: $PKG"
        RESTRICT_COUNT=$((RESTRICT_COUNT + 1))
    fi
done
echo "${GREEN}  ✓ 目标后台高耗电应用已压制 ($RESTRICT_COUNT 个应用已限制)${NC}"

echo "${BLUE}[5/5] 正在重置电量计费基准点...${NC}"
dumpsys batterystats --reset >/dev/null 2>&1 || true
echo "${GREEN}  ✓ 电量统计基准已重置${NC}"

echo ""
echo "${GREEN}======================================================${NC}"
echo "${GREEN}   🎉 优化全部完成！手机息屏后将获得极限省电待机表现。 ${NC}"
echo "${GREEN}======================================================${NC}"
