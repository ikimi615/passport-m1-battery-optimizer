@echo off
chcp 65001 >nul
title Android 待机极限省电与发热优化工具 (免Root一键版)

echo ======================================================
echo    Android 待机极限省电与发热优化工具 (免Root一键版)
echo ======================================================
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

echo [2/3] 正在向手机推送优化脚本...
adb push "%~dp0optimize.sh" /data/local/tmp/optimize.sh >nul
adb shell "chmod +x /data/local/tmp/optimize.sh"

echo [3/3] 正在执行系统深度休眠与耗电优化...
adb shell "sh /data/local/tmp/optimize.sh"

echo.
echo ======================================================
echo  🎉 优化完成！现在可以拔掉数据线，正常使用手机。
echo ======================================================
echo.
pause
