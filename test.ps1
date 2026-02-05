class CreosonClient {

    [string]$creosonUrl = 'http://localhost:9056/creoson'
    [int]$timeout = 60
    [string]$sessionId = ''

    # 核心POST请求方法（重载：支持2个或3个参数，兼容PowerShell 5.1）
    [PSObject] creosonPost([string]$command, [string]$function) {
        return $this.creosonPost($command, $function, @{})
    }

    [PSObject] creosonPost([string]$command, [string]$function, [hashtable]$data) {
        # 构建请求体
        $requestBody = @{
            command  = $command
            function = $function
        }

        # 添加会话ID
        if (-not [string]::IsNullOrEmpty($this.sessionId)) {
            $requestBody['sessionId'] = $this.sessionId
        }

        # 添加数据参数
        if ($data.Count -gt 0) {
            $requestBody['data'] = $data
        }

        # 转换为JSON
        $postData = $requestBody | ConvertTo-Json -Depth 10

        # 调试输出
        Write-Host "[调试] 请求URL: $($this.creosonUrl)"
        Write-Host "[调试] $command.$function $postData"

        # 设置请求头
        $headers = @{
            'Content-Type' = 'application/json; charset=UTF-8'
        }

        try {
            # 发送POST请求
            # PowerShell 5.1 没有 -SkipCertificateCheck，改用忽略SSL错误的全局设置
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
            
            # 创建WebRequest对象，替代Invoke-RestMethod，更精准控制请求（解决Content-Length问题）
            $webRequest = [System.Net.WebRequest]::Create($this.creosonUrl)
            $webRequest.Method = "POST"
            $webRequest.ContentType = "application/json; charset=UTF-8"
            $webRequest.Timeout = $this.timeout * 1000 # 毫秒
            
            # 将POST数据转为UTF8字节数组
            $byteData = [System.Text.Encoding]::UTF8.GetBytes($postData)
            $webRequest.ContentLength = $byteData.Length
            
            # 写入请求体
            $requestStream = $webRequest.GetRequestStream()
            $requestStream.Write($byteData, 0, $byteData.Length)
            $requestStream.Close()
            
            # 获取响应
            $response = $webRequest.GetResponse()
            $responseStream = $response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($responseStream, [System.Text.Encoding]::UTF8)
            $responseContent = $reader.ReadToEnd()
            $reader.Close()
            $response.Close()
            
            # 解析JSON响应
            $result = $responseContent | ConvertFrom-Json

            # 检查Creoson错误
            if ($result.status.error -eq $true) {
                $msg = if ($result.status.message) { $result.status.message } else { '未知错误' }
                if ($msg -eq 'No session found') {
                    throw [Exception]::new("[会话未就绪] $msg", 1001)
                }
                throw [Exception]::new("[Creoson错误] $msg")
            }

            # 保存connect返回的sessionId
            if ($command -eq 'connection' -and $function -eq 'connect' -and $result.sessionId) {
                $this.sessionId = $result.sessionId
                Write-Host "[会话] 获取到官方SessionID: $($this.sessionId)"
            }

            return $result
        }
        catch [System.Net.WebException] {
            $errorMsg = $_.Exception.Message
            if ($_.Exception.Response) {
                $errorStream = $_.Exception.Response.GetResponseStream()
                $errorReader = New-Object System.IO.StreamReader($errorStream)
                $errorContent = $errorReader.ReadToEnd()
                $errorReader.Close()
                $errorMsg += " | 响应内容: $errorContent"
            }
            throw [Exception]::new("[HTTP错误] $errorMsg")
        }
        catch {
            throw
        }
    }

    # 启动Creo
    [void] startCreo([hashtable]$config) {
        Write-Host "【1/6】发送Creo启动命令..."
        $this.creosonPost('connection', 'start_creo', $config)
        Write-Host "【1/6】Creo启动命令发送完成！"
    }

    # 建立Creoson会话
    [void] connect() {
        Write-Host "【2/6】建立Creoson会话..."
        # 调用2个参数的重载方法
        $this.creosonPost('connection', 'connect')
        Write-Host "【2/6】检测Creo会话就绪状态..."
    }

    # 切换Creo工作目录
    [void] creoCd([string]$dirName) {
        Write-Host "【3/6】切换Creo工作目录到: $dirName"
        try {
            $absDir = (Resolve-Path -Path $dirName -ErrorAction Stop).Path
        }
        catch {
            $absDir = $null
        }
        if (-not $absDir -or -not (Test-Path -Path $absDir -PathType Container)) {
            throw [Exception]::new("目录不存在或无效: $dirName（绝对路径: $absDir）")
        }
        $this.creosonPost('creo', 'cd', @{
            dirname = $absDir
        })
        Write-Host "【3/6】工作目录切换成功！"
    }

    # fileOpen方法重载（兼容PowerShell 5.1的参数默认值问题）
    [void] fileOpen([string]$file, [string]$generic) {
        $this.fileOpen($file, $generic, $true, $true)
    }

    [void] fileOpen([string]$file, [string]$generic, [bool]$display, [bool]$activate) {
        Write-Host "【4/6】打开Creo文件: $file"
        $fileName = [System.IO.Path]::GetFileName($file)
        $absFile = Join-Path -Path "D:\mydoc\Creoson_test" -ChildPath $fileName
        try {
            $absFile = (Resolve-Path -Path $absFile -ErrorAction Stop).Path
        }
        catch {
            $absFile = $null
        }

        if (-not $absFile -or -not (Test-Path -Path $absFile -PathType Leaf)) {
            throw [Exception]::new("文件不存在或无效: $file（完整路径: $absFile）")
        }

        $params = @{
            file      = $fileName
            display   = $display
            activate  = $activate
        }
        if (-not [string]::IsNullOrEmpty($generic)) {
            $params['generic'] = $generic
        }

        $this.creosonPost('file', 'open', $params)
        Write-Host "【4/6】文件打开成功！"
    }

    [void] parameterSet([string]$name, [string]$value) {
        $this.parameterSet($name, $value, 'STRING')
    }

    [void] parameterSet([string]$name, [string]$value, [string]$type) {
        Write-Host "【5/6】设置参数 $name = $value（类型: $type）"
        $this.creosonPost('parameter', 'set', @{
            name      = $name
            type      = $type
            value     = $value
            no_create = $false
            designate = $true
        })
        Write-Host "【5/6】参数设置成功！"
    }

    # 保存Creo文件
    [void] fileSave([string]$file) {
        Write-Host "【6/6】保存Creo文件: $file"
        $fileName = [System.IO.Path]::GetFileName($file)
        $absFile = Join-Path -Path "D:\mydoc\Creoson_test" -ChildPath $fileName
        try {
            $absFile = (Resolve-Path -Path $absFile -ErrorAction Stop).Path
        }
        catch {
            $absFile = $null
        }

        if (-not $absFile -or -not (Test-Path -Path $absFile)) {
            throw [Exception]::new("文件路径无效: $file（完整路径: $absFile）")
        }

        $this.creosonPost('file', 'save', @{
            file = $fileName
        })
        Write-Host "【6/6】文件保存成功！"
    }
}

try {
    $client = [CreosonClient]::new()
    $creoConfig = @{
        start_dir      = 'D:\mydoc\Creoson_test'
        start_command  = 'nitro_proe_remote.bat'
        retries        = 5
        use_desktop    = $false
    }

    $client.startCreo($creoConfig)
    $client.connect()
    $client.creoCd('D:\mydoc\Creoson_test')
    $client.fileOpen("fin.prt", "fin")
    $client.parameterSet("test", "PowerShell脚本调用CREOSON添加的参数", "STRING")
    $client.fileSave("fin.prt")

    Write-Host "`n===== 全流程执行完成！====="
}
catch {
    Write-Host "`n===== 执行失败 ====="
    Write-Host "错误详情: $($_.Exception.Message)"
    Write-Host "===================="
    exit 1
}