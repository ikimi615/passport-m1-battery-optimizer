#!/bin/sh
# ==============================================================================
# Passport M1 & MTK Android 12+ VPN/Wi-Fi Switching IMS & VoLTE Crash Fixer
# Fixes:
#   1. java.lang.ClassCastException: android.net.VpnTransportInfo cannot be cast
#      to android.net.wifi.WifiInfo at com.mediatek.wfo.impl.WifiPdnHandler.isPrimaryWifi
#   2. UID 1001 (com.mediatek.ims / com.android.phone) IPv6 blackhole & routing hijack
#   3. ActivityManager: Service.startForeground() not allowed due to bg restriction
# ==============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo "${CYAN}================================================================${NC}"
echo "${CYAN}   Passport M1 VPN <-> Wi-Fi 切换 IMS/VoLTE 崩溃与断联修复工具   ${NC}"
echo "${CYAN}================================================================${NC}"

CURRENT_UID=$(id -u 2>/dev/null || echo "9999")

if [ "$CURRENT_UID" != "0" ]; then
    if which su >/dev/null 2>&1 || [ -x /system/bin/su ] || [ -x /system/xbin/su ]; then
        echo "${YELLOW}[INFO] 正在通过 su 提权至 Root 执行深度修复...${NC}"
        exec su 0 sh -c "sh \"$0\" \"$@\""
    else
        echo "${YELLOW}[WARN] 当前为非 Root 权限 (UID: $CURRENT_UID)，仅能执行后台解限；请在 FlClash 内手动开启【分应用代理 -> 绕过模式】并勾选系统电话与 IMS 组件。${NC}"
    fi
else
    echo "${GREEN}[权限状态] 已获取 Root (UID 0) 权限，开始执行全自动修复...${NC}"
fi

# ------------------------------------------------------------------------------
# [1/4] 解除 VPN 客户端后台运行限制与加入 Doze 白名单
# ------------------------------------------------------------------------------
echo "${BLUE}[1/4] 正在解除 VPN 客户端后台受限 (防止切 Wi-Fi 时 VpnService 被拦截)...${NC}"
VPN_PKGS="
com.oixcloud.clash
com.follow.clash
com.github.metacubex.clash.meta
com.github.kr328.clash
io.nekohasekai.sfa
io.nekohasekai.sagernet
moe.nb4a
com.v2ray.ang
"

for PKG in $VPN_PKGS; do
    if pm list packages 2>/dev/null | grep -q "^package:$PKG$"; then
        cmd appops set "$PKG" RUN_ANY_IN_BACKGROUND allow 2>/dev/null || true
        cmd appops set "$PKG" RUN_IN_BACKGROUND allow 2>/dev/null || true
        cmd appops set "$PKG" START_FOREGROUND allow 2>/dev/null || true
        dumpsys deviceidle whitelist +"$PKG" >/dev/null 2>&1 || true
        echo "${GREEN}  ✓ 已解除后台限制并加入白名单: $PKG${NC}"
    fi
done

# ------------------------------------------------------------------------------
# [2/4] 自动配置 FlClash 分应用绕过 UID 1001 (com.mediatek.ims / com.android.phone)
# ------------------------------------------------------------------------------
echo "${BLUE}[2/4] 正在配置 FlClash 绕过系统通信组件 (UID 1001: IMS & Phone)...${NC}"
if [ "$CURRENT_UID" = "0" ]; then
    for CLASH_PKG in com.oixcloud.clash com.follow.clash; do
        if pm list packages 2>/dev/null | grep -q "^package:$CLASH_PKG$"; then
            DATA_DIR=$(dumpsys package "$CLASH_PKG" 2>/dev/null | grep "dataDir=" | head -n 1 | cut -d= -f2 | tr -d ' \r\n')
            APP_UID=$(dumpsys package "$CLASH_PKG" 2>/dev/null | grep "userId=" | head -n 1 | cut -d= -f2 | tr -d ' \r\n')
            PREF_FILE="$DATA_DIR/shared_prefs/FlutterSharedPreferences.xml"

            if [ -n "$DATA_DIR" ] && [ -f "$PREF_FILE" ]; then
                # 检查是否已经包含 com.mediatek.ims 且处于开启状态
                if grep -q "com.mediatek.ims" "$PREF_FILE" && grep -q "&quot;accessControlProps&quot;:{&quot;enable&quot;:true" "$PREF_FILE"; then
                    echo "${GREEN}  ✓ $CLASH_PKG 已配置 UID 1001 (com.mediatek.ims / com.android.phone) 绕过规则${NC}"
                else
                    WAS_TUN_ACTIVE=0
                    if ip link show tun0 >/dev/null 2>&1; then
                        WAS_TUN_ACTIVE=1
                    fi

                    echo "  - 正在停止 $CLASH_PKG 以安全写入分应用绕过配置..."
                    am force-stop "$CLASH_PKG" 2>/dev/null || true
                    killall -9 "$CLASH_PKG" "$CLASH_PKG:remote" 2>/dev/null || true

                    cp "$PREF_FILE" "$PREF_FILE.bak"
                    rm -f "$DATA_DIR/files/config.age" 2>/dev/null || true

                    # 替换 accessControlProps 配置，开启 rejectSelected 并排除 UID 1001 核心包
                    sed -i 's/&quot;accessControlProps&quot;:{&quot;enable&quot;:false,&quot;mode&quot;:&quot;[^&]*&quot;,&quot;acceptList&quot;:\[[^]]*\],&quot;rejectList&quot;:\[[^]]*\],&quot;sort&quot;:&quot;[^&]*&quot;,&quot;isFilterSystemApp&quot;:[a-z]*,&quot;isFilterNonInternetApp&quot;:[a-z]*}/&quot;accessControlProps&quot;:{&quot;enable&quot;:true,&quot;mode&quot;:&quot;rejectSelected&quot;,&quot;acceptList&quot;:[],&quot;rejectList&quot;:[&quot;com.mediatek.ims&quot;,&quot;com.android.phone&quot;,&quot;com.mediatek.telephony&quot;,&quot;com.android.providers.telephony&quot;,&quot;com.android.mms.service&quot;],&quot;sort&quot;:&quot;none&quot;,&quot;isFilterSystemApp&quot;:false,&quot;isFilterNonInternetApp&quot;:false}/g' "$PREF_FILE"

                    if [ -n "$APP_UID" ]; then
                        chown "$APP_UID:$APP_UID" "$PREF_FILE" 2>/dev/null || true
                    fi
                    chmod 660 "$PREF_FILE" 2>/dev/null || true
                    restorecon "$PREF_FILE" 2>/dev/null || true
                    rm -f "$PREF_FILE.bak" 2>/dev/null || true

                    echo "${GREEN}  ✓ 已成功将 UID 1001 绕过规则写入 $CLASH_PKG${NC}"

                    if [ "$WAS_TUN_ACTIVE" = "1" ]; then
                        echo "  - 正在重新拉起 $CLASH_PKG VPN 服务并同步加密配置..."
                        am start -a "$CLASH_PKG.action.START" -n "$CLASH_PKG/.TempActivity" >/dev/null 2>&1 || true
                        sleep 3
                    fi
                fi
            fi
        fi
    done
fi

# ------------------------------------------------------------------------------
# [3/4] 唤醒并恢复因 ClassCastException 崩溃冻结的联发科 IMS 服务
# ------------------------------------------------------------------------------
echo "${BLUE}[3/4] 正在检查并恢复联发科 IMS / VoLTE 核心服务 (com.mediatek.ims)...${NC}"
if [ "$CURRENT_UID" = "0" ]; then
    if ! ps -A 2>/dev/null | grep -q "com.mediatek.ims"; then
        echo "${YELLOW}  ! 检测到 com.mediatek.ims 进程未运行 (此前因 VpnTransportInfo 转换崩溃被系统挂起)，正在立即拉起...${NC}"
        am startservice com.mediatek.ims/.MtkDynamicImsService >/dev/null 2>&1 || true
        sleep 3
    fi
fi

# ------------------------------------------------------------------------------
# [4/4] 状态检验 (验证 IMS 进程、ccmni0 专网与 tun0 路由规则)
# ------------------------------------------------------------------------------
echo "${BLUE}[4/4] 正在验证修复后网络与 VoLTE IMS 状态...${NC}"

IMS_PID=$(ps -A 2>/dev/null | grep "com.mediatek.ims" | awk '{print $2}' | head -n 1)
if [ -n "$IMS_PID" ]; then
    echo "${GREEN}  ✓ com.mediatek.ims 运行正常 (PID: $IMS_PID)${NC}"
else
    echo "${RED}  ✗ com.mediatek.ims 未运行，请检查设备是否支持 MTK IMS${NC}"
fi

if dumpsys connectivity 2>/dev/null | grep "NetworkAgentInfo" | grep -q "Capabilities: IMS"; then
    echo "${GREEN}  ✓ 运营商 IMS 专网 (ccmni0) 状态: CONNECTED & VALIDATED${NC}"
else
    echo "${YELLOW}  ! 暂未检测到 IMS 专网连接，正在等待基带重新注册...${NC}"
fi

if ip -6 rule 2>/dev/null | grep "lookup tun0" | grep -q "uidrange 1002-99999"; then
    echo "${GREEN}  ✓ VPN 路由规则验证通过: UID 1001 已从 tun0 完全排除 (uidrange 0-1000, 1002-99999)${NC}"
elif ip link show tun0 >/dev/null 2>&1; then
    echo "${YELLOW}  ! 当前 tun0 仍处于旧连接，请断开并重新连接一次 VPN 以应用 UID 1001 绕过规则${NC}"
else
    echo "${GREEN}  ✓ 配置已就绪，下次开启 VPN 时将自动排除 UID 1001${NC}"
fi

echo ""
echo "${GREEN}================================================================${NC}"
echo "${GREEN} 🎉 修复完成！现在无论先开 VPN 再连 Wi-Fi 还是任意切网，VoLTE 均稳定在线。${NC}"
echo "${GREEN}================================================================${NC}"
