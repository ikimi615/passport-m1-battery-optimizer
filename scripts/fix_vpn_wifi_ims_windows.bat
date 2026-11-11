@echo off
chcp 65001 >nul
title Passport M1 VPN与Wi-Fi切换导致IMS/VoLTE错误 一键修复工具

echo ==============================================================
echo   Passport M1 VPN ^<--^> Wi-Fi 切换导致 IMS/VoLTE 错误修复工具
echo ==============================================================
echo.
echo [1/3] 正在检测已连接的手机设备...
adb devices
echo.

adb get-state 1>nul 2>nul
if %errorlevel% neq 0 (
    echo [错误] 未检测到手机，请检查：
    echo 1. 手机是否已用数据线连接电脑；
    echo 2. 手机是否已进入【开发者选项】并开启【USB 调试】；
    echo 3. 手机屏幕弹出“允许 USB 调试”时是否已点击允许。
    echo.
    pause
    exit /b
)

echo [2/3] 正在向手机推送 IMS/VPN 修复脚本...
adb push "%~dp0fix_vpn_wifi_ims.sh" /data/local/tmp/fix_vpn_wifi_ims.sh >nul
adb shell "chmod +x /data/local/tmp/fix_vpn_wifi_ims.sh"

echo [3/3] 正在执行 VPN 后台解限、UID 1001 分流绕过与 IMS 服务恢复...
adb shell "sh /data/local/tmp/fix_vpn_wifi_ims.sh"

echo.
echo ==============================================================
echo  🎉 修复完成！现在先开 VPN 再连 Wi-Fi 也不会出现 IMS 错误了。
echo ==============================================================
echo.
pause
