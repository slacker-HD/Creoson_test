@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

:: ============================================
:: Creo CREOSON 自动化操作脚本
:: ============================================

:: 配置参数
set "CREOSON_URL=http://localhost:9056/creoson"
set "WORK_DIR=D:\mydoc\Creoson_test"
set "TARGET_FILE=fin.prt"
set "START_COMMAND=nitro_proe_remote.bat"
set "TIMEOUT=60"

set "SESSION_ID="

echo ============================================
echo    Creo CREOSON 自动化操作脚本
echo ============================================
echo.

:: 步骤 1.1: 创建会话
echo [1/6] 正在启动 Creo 会话...

curl -X POST "%CREOSON_URL%" -H "Content-Type: application/json" --max-time %TIMEOUT% -k -s ^
  -d "{\"command\":\"connection\",\"function\":\"start_creo\",\"data\":{\"start_dir\":\"%WORK_DIR:\=\\\\%\",\"start_command\":\"%START_COMMAND%\",\"retries\":5,\"use_desktop\":false}}" ^
  > response.json

call :CheckError "启动Creo"
if errorlevel 1 goto :ErrorExit

echo [✓] Creo 启动成功
echo.

:: 步骤 1.2: 连接会话
echo [2/6] 正在连接会话并获取 Session ID...

curl -X POST "%CREOSON_URL%" -H "Content-Type: application/json" --max-time %TIMEOUT% -k -s ^
  -d "{\"command\":\"connection\",\"function\":\"connect\",\"data\":{\"timeout\":60000}}" ^
  > response.json

for /f "delims=" %%i in ('powershell -NoProfile -Command "(Get-Content response.json | ConvertFrom-Json).sessionId" 2^>nul') do set "SESSION_ID=%%i"

if "!SESSION_ID!"=="" (
    for /f "tokens=*" %%a in ('findstr /R /C:"\"sessionId\"[ ]*:[ ]*\"[0-9]*\"" response.json') do (
        set "line=%%a"
        set "line=!line:*sessionId\"=!"
        for /f "delims=" %%b in ("!line!") do (
            set "temp=%%b"
            set "temp=!temp::=!"
            set "temp=!temp:\"=!"
            set "temp=!temp: =!"
            set "temp=!temp:,=!"
            if not defined SESSION_ID set "SESSION_ID=!temp!"
        )
    )
)

set "SESSION_ID=!SESSION_ID:"=!"
set "SESSION_ID=!SESSION_ID:,=!"
set "SESSION_ID=!SESSION_ID: =!"

if "!SESSION_ID!"=="" (
    echo [✗] 未能获取 Session ID
    goto :ErrorExit
)

echo [✓] 连接成功，Session ID: !SESSION_ID!
echo.

:: 步骤 1.3: 切换工作目录
echo [3/6] 正在切换工作目录...

curl -X POST "%CREOSON_URL%" -H "Content-Type: application/json" --max-time %TIMEOUT% -k -s ^
  -d "{\"command\":\"creo\",\"function\":\"cd\",\"sessionId\":\"!SESSION_ID!\",\"data\":{\"dirname\":\"%WORK_DIR:\=\\\\%\"}}" ^
  > response.json

call :CheckError "切换工作目录"
if errorlevel 1 goto :ErrorExit

echo [✓] 工作目录切换成功
echo.

:: 步骤 1.4: 打开文件
echo [4/6] 正在打开文件: %TARGET_FILE%...

curl -X POST "%CREOSON_URL%" -H "Content-Type: application/json" --max-time %TIMEOUT% -k -s ^
  -d "{\"command\":\"file\",\"function\":\"open\",\"sessionId\":\"!SESSION_ID!\",\"data\":{\"file\":\"%TARGET_FILE%\",\"display\":true,\"activate\":true}}" ^
  > response.json

call :CheckError "打开文件"
if errorlevel 1 goto :ErrorExit

echo [✓] 文件打开成功
echo.

:: 步骤 1.5: 添加参数
echo [5/6] 正在添加参数...

curl -X POST "%CREOSON_URL%" -H "Content-Type: application/json" --max-time %TIMEOUT% -k -s ^
  -d "{\"command\":\"parameter\",\"function\":\"set\",\"sessionId\":\"!SESSION_ID!\",\"data\":{\"name\":\"test\",\"type\":\"STRING\",\"value\":\"批处理调用Curl手动添加参数\",\"no_create\":false,\"designate\":true}}" ^
  > response.json

call :CheckError "添加参数"
if errorlevel 1 goto :ErrorExit

echo [✓] 参数添加成功
echo.

:: 步骤 1.6: 保存文件
echo [6/6] 正在保存文件...

curl -X POST "%CREOSON_URL%" -H "Content-Type: application/json" --max-time %TIMEOUT% -k -s ^
  -d "{\"command\":\"file\",\"function\":\"save\",\"sessionId\":\"!SESSION_ID!\",\"data\":{\"file\":\"%TARGET_FILE%\"}}" ^
  > response.json

call :CheckError "保存文件"
if errorlevel 1 goto :ErrorExit

echo [✓] 文件保存成功
echo.

:: 完成
echo ============================================
echo    所有操作执行成功！
echo ============================================
goto :CleanExit

:CheckError
findstr /C:"\"error\":false" response.json >nul
if errorlevel 1 (
    echo [✗] %~1 失败
    type response.json
    exit /b 1
)
exit /b 0

:ErrorExit
echo.
echo ============================================
echo    执行过程中出现错误
echo ============================================

:CleanExit
if exist response.json del response.json
endlocal
exit /b 0