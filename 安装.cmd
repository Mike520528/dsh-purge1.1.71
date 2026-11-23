@echo off
chcp 936 >nul
cd /d "%~dp0"
echo.
echo   dsh-purge 1.1.71 installer
echo   ----------------------------------------
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
set RC=%errorlevel%
echo.
if not "%RC%"=="0" (
  echo   [x] 安装未完成，退出码 %RC%
  echo       3 = 检测到冲突插件（Xsdsh-purge 或 community），请先卸载它
  echo       2 = DSH 版本不是 0.2.0-rc.2
  echo       1 = 找不到 DSH 或流程文件
) else (
  echo   [+] 完成，请完全退出并重启 DeepSeek Harness
)
echo.
pause