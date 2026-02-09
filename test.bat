@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

rem ============================================
rem Creo CREOSON 自动化操作脚本 (纯CMD版本)
rem ============================================

rem 配置参数
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

rem 步骤 1.1: 创建会话
echo [1/6] 正在启动 Creo 会话...

curl -X POST "%CREOSON_URL%" -H "Content-Type: application/json" --max-time %TIMEOUT% -k -s ^
  -d "{\"command\":\"connection\",\"function\":\"start_creo\",\"data\":{\"start_dir\":\"%WORK_DIR:\=\\\\%\",\"start_command\":\"%START_COMMAND%\",\"retries\":5,\"use_desktop\":false}}" ^
  > response.json

call :CheckError "启动Creo"
if errorlevel 1 goto :ErrorExit

echo [✓] Creo 启动成功
echo.

rem 步骤 1.2: 连接会话
echo [2/6] 正在连接会话并获取 Session ID...

curl -X POST "%CREOSON_URL%" -H "Content-Type: application/json" --max-time %TIMEOUT% -k -s ^
  -d "{\"command\":\"connection\",\"function\":\"connect\",\"data\":{\"timeout\":60000}}" ^
  > response.json

rem 纯CMD方式解析JSON中的sessionId
call :ParseSessionId
if "!SESSION_ID!"=="" (
    echo [✗] 未能获取 Session ID
    type response.json
    goto :ErrorExit
)

echo [✓] 连接成功，Session ID: !SESSION_ID!
echo.

rem 步骤 1.3: 切换工作目录
echo [3/6] 正在切换工作目录...

curl -X POST "%CREOSON_URL%" -H "Content-Type: application/json" --max-time %TIMEOUT% -k -s ^
  -d "{\"command\":\"creo\",\"function\":\"cd\",\"sessionId\":\"!SESSION_ID!\",\"data\":{\"dirname\":\"%WORK_DIR:\=\\\\%\"}}" ^
  > response.json

call :CheckError "切换工作目录"
if errorlevel 1 goto :ErrorExit

echo [✓] 工作目录切换成功
echo.

rem 步骤 1.4: 打开文件
echo [4/6] 正在打开文件: %TARGET_FILE%...

curl -X POST "%CREOSON_URL%" -H "Content-Type: application/json" --max-time %TIMEOUT% -k -s ^
  -d "{\"command\":\"file\",\"function\":\"open\",\"sessionId\":\"!SESSION_ID!\",\"data\":{\"file\":\"%TARGET_FILE%\",\"display\":true,\"activate\":true}}" ^
  > response.json

call :CheckError "打开文件"
if errorlevel 1 goto :ErrorExit

echo [✓] 文件打开成功
echo.

rem 步骤 1.5: 添加参数
echo [5/6] 正在添加参数...

curl -X POST "%CREOSON_URL%" -H "Content-Type: application/json" --max-time %TIMEOUT% -k -s ^
  -d "{\"command\":\"parameter\",\"function\":\"set\",\"sessionId\":\"!SESSION_ID!\",\"data\":{\"name\":\"test\",\"type\":\"STRING\",\"value\":\"批处理调用Curl手动添加参数\",\"no_create\":false,\"designate\":true}}" ^
  > response.json

call :CheckError "添加参数"
if errorlevel 1 goto :ErrorExit

echo [✓] 参数添加成功
echo.

rem 步骤 1.6: 保存文件
echo [6/6] 正在保存文件...

curl -X POST "%CREOSON_URL%" -H "Content-Type: application/json" --max-time %TIMEOUT% -k -s ^
  -d "{\"command\":\"file\",\"function\":\"save\",\"sessionId\":\"!SESSION_ID!\",\"data\":{\"file\":\"%TARGET_FILE%\"}}" ^
  > response.json

call :CheckError "保存文件"
if errorlevel 1 goto :ErrorExit

echo [✓] 文件保存成功
echo.

rem 完成
echo ============================================
echo    所有操作执行成功！
echo ============================================
goto :CleanExit

rem ============================================
rem 子程序: 解析Session ID (纯CMD实现)
rem ============================================
:ParseSessionId
set "SESSION_ID="
set "jsonline="

rem 读取包含sessionId的行
for /f "delims=" %%a in ('findstr /i /c:"\"sessionId\"" response.json') do (
    set "jsonline=%%a"
    goto :GotLine
)

:GotLine
if "!jsonline!"=="" exit /b 1

rem 提取sessionId值
set "temp=!jsonline!"
set "marker="sessionId""
call :GetSubstringAfter "!temp!" "!marker!" temp

rem 去掉冒号
set "temp=!temp::=!"

rem 去掉双引号
set "temp=!temp:"=!"

rem 去掉空格
set "temp=!temp: =!"

rem 提取逗号前的数字部分
for /f "delims=," %%b in ("!temp!") do set "SESSION_ID=%%b"

exit /b 0

rem ============================================
rem 子程序: 获取标记后的子字符串
rem ============================================
:GetSubstringAfter
set "str=%~1"
set "marker=%~2"

rem 查找标记位置并提取之后的内容
set "test=!str:*%marker%=!"
if "!test!"=="!str!" (
    rem 未找到标记
    set "%~3="
    exit /b 1
)

rem 去掉标记及其前面的所有内容
set "result=!str:*%marker%=!"
set "%~3=!result!"

exit /b 0

rem ============================================
rem 子程序: 检查错误
rem ============================================
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