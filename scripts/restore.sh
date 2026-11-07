#!/bin/sh
# ==============================================================================
# Android Battery Settings Restore (Rollback to Stock Defaults)
# ==============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo "${CYAN}======================================================${NC}"
echo "${CYAN}       恢复 Android 原厂默认电量与休眠配置            ${NC}"
echo "${CYAN}======================================================${NC}"

CURRENT_UID=$(id -u 2>/dev/null || echo "9999")

if [ "$CURRENT_UID" != "0" ] && [ "$CURRENT_UID" != "2000" ]; then
    if which su >/dev/null 2>&1 || [ -x /system/bin/su ] || [ -x /system/xbin/su ]; then
        echo "${YELLOW}[INFO] 正在申请 Root 提权 (su)...${NC}"
        exec su -c "sh \"$0\" \"$@\""
    else
        echo "${RED}[ERROR] 当前权限不足。本脚本需要 Root 权限或 ADB/Shizuku (Shell) 权限。${NC}"
        exit 1
    fi
fi

echo "正在将 DeviceIdle (Doze) 休眠参数重置为原厂默认值..."
dumpsys deviceidle reset >/dev/null 2>&1 || true

echo "正在恢复 Wi-Fi / 蓝牙扫描默认状态..."
settings delete global wifi_scan_always_enabled 2>/dev/null || true
settings delete global ble_scan_always_enabled 2>/dev/null || true
settings delete global adaptive_connectivity_enabled 2>/dev/null || true

echo "正在恢复应用后台运行限制 (解除 AppOps 限制)..."
RESTRICTED_APPS="
com.xingin.xhs
com.weather.mjweather
com.tencent.android.qqdownloader
com.ss.android.ugc.aweme
com.taobao.taobao
com.jingdong.app.mall
com.autonavi.minimap
"

for PKG in $RESTRICTED_APPS; do
    if pm list packages | grep -q "^package:$PKG$"; then
        cmd appops set "$PKG" RUN_ANY_IN_BACKGROUND default 2>/dev/null || true
        cmd appops set "$PKG" RUN_IN_BACKGROUND default 2>/dev/null || true
        echo "  - 已恢复: $PKG"
    fi
done

echo ""
echo "${GREEN}✓ 所有电量与网络参数已成功恢复为系统默认设置！${NC}"
