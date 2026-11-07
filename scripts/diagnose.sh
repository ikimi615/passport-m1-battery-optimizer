#!/bin/sh
# ==============================================================================
# Android Battery & Standby Diagnostic Tool
# Calculates real-time deep sleep ratio, discharge speed, and wakelock culprits
# ==============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo "${CYAN}======================================================${NC}"
echo "${CYAN}        Android 耗电分析与深度睡眠诊断工具           ${NC}"
echo "${CYAN}======================================================${NC}"

CURRENT_UID=$(id -u 2>/dev/null || echo "9999")

if [ "$CURRENT_UID" != "0" ] && [ "$CURRENT_UID" != "2000" ]; then
    if which su >/dev/null 2>&1 || [ -x /system/bin/su ] || [ -x /system/xbin/su ]; then
        echo "${YELLOW}[INFO] 检测到当前非 Root，正在尝试申请 Root 提权 (su)...${NC}"
        exec su -c "sh \"$0\" \"$@\""
    else
        echo "${RED}[ERROR] 当前权限不足。本诊断工具需要 Root 权限或 ADB/Shizuku (Shell) 权限。${NC}"
        exit 1
    fi
fi

echo "${BOLD}1. 电池硬件状态：${NC}"
BATT_LEVEL=$(dumpsys battery | grep "^  level:" | awk '{print $2}')
BATT_TEMP=$(dumpsys battery | grep "^  temperature:" | awk '{print $2}')
BATT_STATUS=$(dumpsys battery | grep "^  status:" | awk '{print $2}')
BATT_VOLT=$(dumpsys battery | grep "^  voltage:" | awk '{print $2}')

# Temperature format (273 -> 27.3 C)
if [ -n "$BATT_TEMP" ]; then
    TEMP_C=$(awk "BEGIN {print $BATT_TEMP / 10}")
else
    TEMP_C="N/A"
fi

STATUS_DESC="未知"
case "$BATT_STATUS" in
    2) STATUS_DESC="充电中 (Charging)" ;;
    3) STATUS_DESC="放电中 (Discharging)" ;;
    4) STATUS_DESC="未充电 (Not charging)" ;;
    5) STATUS_DESC="已充满 (Full)" ;;
esac

echo "  当前电量: ${GREEN}${BATT_LEVEL}%${NC}"
echo "  机身温度: ${GREEN}${TEMP_C} °C${NC}"
echo "  供电状态: $STATUS_DESC (电压: ${BATT_VOLT} mV)"

echo ""
echo "${BOLD}2. 深度睡眠与运行时间分析 (BatteryStats)：${NC}"
STATS_SUMMARY=$(dumpsys batterystats --charged | grep -E "Total run time:|Discharge:|Screen on:" || true)
echo "$STATS_SUMMARY" | sed 's/^/  /'

echo ""
echo "${BOLD}3. 极速休眠状态 (DeviceIdle / Doze)：${NC}"
DOZE_STATE=$(dumpsys deviceidle | grep -E "mState=|mLightState=" | tr '\n' ' ' || true)
echo "  休眠状态机: ${GREEN}${DOZE_STATE}${NC}"
echo "  近期休眠历史 (前 5 条):"
dumpsys deviceidle | grep -A 6 "Idling history:" | head -n 6 | sed 's/^/  /'

echo ""
echo "${BOLD}4. 后台唤醒锁阻碍检测 (WakeLock Blockers)：${NC}"
BLOCKERS=$(dumpsys power | grep -A 5 "Suspend Blockers:" | grep "ref count" || true)
echo "  系统内核挂起阻碍计数:"
echo "$BLOCKERS" | sed 's/^/    /'

echo ""
echo "${BOLD}5. 近期电量消耗最大的应用 Top 5：${NC}"
dumpsys batterystats --charged | grep -A 8 "Estimated power use (mAh):" | head -n 8 | sed 's/^/  /'

echo ""
echo "${CYAN}======================================================${NC}"
echo "${GREEN}诊断完成。若 'ref count=0' 且深度睡眠时间占比 > 90%，说明休眠状态极佳！${NC}"
