Option Explicit

' 全局配置
Dim creosonUrl, sessionId
creosonUrl = "http://localhost:9056/creoson"
sessionId = ""

' 主程序入口
On Error Resume Next
Call MainProcess()

' 错误处理
If Err.Number <> 0 Then
    WScript.Echo vbCrLf & "===== Execution Failed ====="
    WScript.Echo "Error Message: " & Err.Description
    WScript.Echo "Error Line: " & Err.Line
    WScript.Echo "Error Code: " & Err.Number
    WScript.Echo "============================"
    WScript.Quit 1
End If
On Error GoTo 0

' 核心执行流程
Sub MainProcess()
    Dim fso
    Set fso = CreateObject("Scripting.FileSystemObject")
    
    ' 预检查目录
    If Not fso.FolderExists("D:\mydoc\Creoson_test") Then
        Err.Raise 1003, , "Directory not found: D:\mydoc\Creoson_test"
    End If
    
    ' 1. 启动Creo
    WScript.Echo "[1/6] Sending Creo start command..."
    Call CreosonPost("connection", "start_creo", _
        "{""start_dir"":""D:\\mydoc\\Creoson_test"",""start_command"":""nitro_proe_remote.bat"",""retries"":5,""use_desktop"":false}")
    WScript.Echo "[1/6] Creo start command sent!"
    
    ' 2. 建立连接（获取并保存sessionId）
    WScript.Echo "[2/6] Creating Creoson session..."
    Dim connectResp
    connectResp = CreosonPost("connection", "connect", "{}")
    
    ' ✅ 分割法提取sessionId（彻底绕开索引计算）
    sessionId = SplitSessionId(connectResp)
    If sessionId = "" Then
        Err.Raise 1005, , "Failed to get sessionId! Response: " & connectResp
    End If
    WScript.Echo "[Session] Got SessionID: " & sessionId
    WScript.Echo "[2/6] Session connected!"
    
    ' 3. 切换目录（自动携带sessionId）
    WScript.Echo "[3/6] Changing working directory..."
    Call CreosonPost("creo", "cd", _
        "{""dirname"":""D:\\mydoc\\Creoson_test""}")
    WScript.Echo "[3/6] Directory changed!"
    
    ' 4. 打开文件
    WScript.Echo "[4/6] Opening fin.prt..."
    If Not fso.FileExists("D:\mydoc\Creoson_test\fin.prt") Then
        Err.Raise 1004, , "File not found: D:\mydoc\Creoson_test\fin.prt"
    End If
    Call CreosonPost("file", "open", _
        "{""file"":""fin.prt"",""generic"":""fin"",""display"":true,""activate"":true}")
    WScript.Echo "[4/6] File opened!"
    
    ' 5. 设置参数
    WScript.Echo "[5/6] Setting parameter 'test'..."
    Call CreosonPost("parameter", "set", _
        "{""name"":""test"",""type"":""STRING"",""value"":""VBS调用CREOSON添加的参数"",""no_create"":false,""designate"":true}")
    WScript.Echo "[5/6] Parameter set!"
    
    ' 6. 保存文件
    WScript.Echo "[6/6] Saving file..."
    Call CreosonPost("file", "save", _
        "{""file"":""fin.prt""}")
    WScript.Echo "[6/6] File saved!"
    
    WScript.Echo vbCrLf & "===== All Process Completed Successfully! ====="
End Sub

' 核心函数：复刻PHP的creosonPost方法
Function CreosonPost(command, func, dataJson)
    Dim http, response, reqJson
    
    ' 1. 构建请求体
    reqJson = "{""command"":""" & command & """,""function"":""" & func & """"
    
    ' 2. 自动添加sessionId
    If Trim(sessionId) <> "" Then
        reqJson = reqJson & ",""sessionId"":""" & sessionId & """"
    End If
    
    ' 3. 添加data参数
    If dataJson <> "{}" Then
        reqJson = reqJson & ",""data"":" & dataJson
    End If
    reqJson = reqJson & "}"
    
    ' 调试输出
    WScript.Echo "[Debug] Send JSON: " & reqJson
    
    ' 4. 发送HTTP请求
    Set http = CreateObject("MSXML2.XMLHTTP")
    http.open "POST", creosonUrl, False
    http.setRequestHeader "Content-Type", "application/json; charset=UTF-8"
    http.send reqJson
    
    ' 5. 检查HTTP状态
    If http.Status <> 200 Then
        Err.Raise 1001, , "HTTP Error: " & http.Status & " - " & http.responseText
    End If
    
    ' 6. 获取响应
    response = http.responseText
    WScript.Echo "[Debug] Response: " & response
    
    ' 7. 检查Creoson错误
    If InStr(1, response, """error"":true", 1) > 0 Then
        Err.Raise 1002, , "Creoson Error: " & SplitErrorMsg(response)
    End If
    
    CreosonPost = response
End Function

' ✅ 分割法提取SessionID（无索引计算，100%可靠）
Function SplitSessionId(jsonStr)
    Dim arr1, arr2, temp
    ' 第一步：按"sessionId":"分割字符串
    arr1 = Split(jsonStr, """sessionId"":""")
    If UBound(arr1) < 1 Then
        SplitSessionId = ""
        Exit Function
    End If
    
    ' 第二步：取分割后的第二部分，再按"分割
    temp = arr1(1)
    arr2 = Split(temp, """")
    
    ' 第三步：第一部分就是纯sessionId
    If UBound(arr2) >= 0 Then
        SplitSessionId = Trim(arr2(0))
    Else
        SplitSessionId = ""
    End If
End Function

' 分割法提取错误信息
Function SplitErrorMsg(jsonStr)
    Dim arr1, arr2, temp
    arr1 = Split(jsonStr, """message"":""")
    If UBound(arr1) < 1 Then
        SplitErrorMsg = "Unknown Error"
        Exit Function
    End If
    
    temp = arr1(1)
    arr2 = Split(temp, """")
    If UBound(arr2) >= 0 Then
        SplitErrorMsg = Trim(arr2(0))
    Else
        SplitErrorMsg = "Unknown Error"
    End If
End Function