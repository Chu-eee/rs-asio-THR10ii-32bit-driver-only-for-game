@echo off
setlocal enabledelayedexpansion
rem ================================================================
rem  restore_32bit_asio.cmd
rem  恢复 THR-II 的 32 位 ASIO 用户态组件（DLL + 注册表）
rem  使用方式：右键本脚本 -> 以管理员身份运行
rem  可选：把本地已有的 v1.0.0.0 安装包（zip 或 exe）拖到本脚本图标上，免去下载
rem  原则：不安装任何内核驱动，不触碰 64 位驱动栈，不影响 Cubase / Win11 内存完整性
rem ================================================================
cd /d "%~dp0"

net session >nul 2>&1
if errorlevel 1 (
  echo [错误] 需要管理员权限。请右键本脚本 - 以管理员身份运行。
  pause
  exit /b 1
)

rem ---- 1. 确定 v1 安装包来源 ----
set "SRC=%~1"
if not defined SRC set "SRC="
if defined SRC if not exist "%SRC%" set "SRC="

if not defined SRC (
  echo [1/5] 未指定安装包，从 Yamaha 官网下载 v1.0.0.0 ...
  curl.exe -L -sS --ssl-no-revoke --connect-timeout 20 -o "%TEMP%\yamaha_thrii_v1.zip" "https://usa.yamaha.com/files/download/software/7/1382387/Yamaha_Driver_THRII_v1.0.0.0_Installer.exe.zip"
  if errorlevel 1 (
    echo [错误] 下载失败。
    echo        请到 Yamaha 官网下载 "Yamaha Driver THRII v1.0.0.0" 安装包，
    echo        然后把安装包文件拖到本脚本图标上重试。
    pause
    exit /b 1
  )
  set "SRC=%TEMP%\yamaha_thrii_v1.zip"
)

rem ---- 2. 解包出安装 exe ----
set "WORK=%TEMP%\thrii_v1_pkg"
if exist "%WORK%" rmdir /s /q "%WORK%"
mkdir "%WORK%"
echo [2/5] 解包安装包...
set "INSTALLER=%SRC%"
echo %SRC% | findstr /i "\.zip$" >nul
if not errorlevel 1 (
  powershell -NoProfile -Command "Expand-Archive -LiteralPath '%SRC%' -DestinationPath '%WORK%' -Force" >nul 2>&1
  for /f "delims=" %%f in ('dir /b /s "%WORK%\*.exe" 2^>nul') do set "INSTALLER=%%f"
)

rem ---- 3. 解 NSIS（需要 7-Zip）----
set "SZ="
for %%p in ("%ProgramFiles%\7-Zip\7z.exe" "%ProgramFiles(x86)%\7-Zip\7z.exe" "%ProgramW6432%\7-Zip\7z.exe") do if exist %%p set "SZ=%%~p"
if not defined SZ (
  echo [错误] 未找到 7-Zip。请先安装 7-Zip（https://www.7-zip.org）后重试。
  pause
  exit /b 1
)
echo [3/5] 用 7-Zip 解出 32 位 ASIO 组件...
"%SZ%" x "%INSTALLER%" -o"%WORK%\x" -y >nul 2>&1

rem ---- 4. 复制 DLL 到 SysWOW64 ----
echo [4/5] 复制 DLL 到 SysWOW64...
copy /y "%WORK%\x\Driver Archive\THRII\YamahaTHRIIAsio_OnInterposer.dll" "%WINDIR%\SysWOW64\" >nul
copy /y "%WORK%\x\Driver Archive\THRII\InterposerTHRIIBackend.dll"     "%WINDIR%\SysWOW64\" >nul

rem ---- 5. 写入 32 位 ASIO 注册表项 ----
echo [5/5] 写入注册表...
reg add "HKLM\SOFTWARE\WOW6432Node\ASIO\ASIO THRII" /v CLSID /d "{4A1C1DA6-7749-41D5-A13F-AED70386C0F8}" /f >nul
reg add "HKLM\SOFTWARE\WOW6432Node\ASIO\ASIO THRII" /v Description /d "ASIO THRII" /f >nul
reg add "HKLM\SOFTWARE\WOW6432Node\Classes\CLSID\{4A1C1DA6-7749-41D5-A13F-AED70386C0F8}\InprocServer32" /ve /d "%WINDIR%\SysWow64\YamahaTHRIIAsio_OnInterposer.dll" /f >nul
reg add "HKLM\SOFTWARE\WOW6432Node\Classes\CLSID\{4A1C1DA6-7749-41D5-A13F-AED70386C0F8}\InprocServer32" /v ThreadingModel /d "Apartment" /f >nul

echo.
echo ============ 校验结果 ============
if exist "%WINDIR%\SysWOW64\YamahaTHRIIAsio_OnInterposer.dll" (echo  [OK] YamahaTHRIIAsio_OnInterposer.dll) else (echo  [FAIL] ASIO DLL 缺失)
if exist "%WINDIR%\SysWOW64\InterposerTHRIIBackend.dll"       (echo  [OK] InterposerTHRIIBackend.dll)       else (echo  [FAIL] 后端 DLL 缺失)
reg query "HKLM\SOFTWARE\WOW6432Node\ASIO\ASIO THRII" >nul 2>&1 && (echo  [OK] ASIO THRII 注册项) || (echo  [FAIL] ASIO THRII 注册项)
echo ==================================
echo.
echo 完成。下一步（见 solution-layout 文档）：
echo   1. rs_asio release 的 RS_ASIO.dll / avrt.dll 放进游戏根目录
echo   2. configs\RS_ASIO.ini 复制到游戏根目录
echo   3. 确认 Rocksmith.ini 的 ExclusiveMode=1
echo   4. 不要运行 Voicemeeter，直接启动游戏
pause