<?php
// 开启错误显示
error_reporting(E_ALL);
ini_set('display_errors', 1);
ini_set('default_charset', 'UTF-8');


class CreosonClient
{
    private $creosonUrl = 'http://localhost:9056/creoson';
    private $timeout = 60;
    private $sessionId = '';
    private $maxReadyChecks = 10;
    private $checkInterval = 1;


    public function creosonPost($command, $function, $data = [])
    {
        $requestBody = [
            'command' => $command,
            'function' => $function
        ];

        if (!empty($this->sessionId)) {
            $requestBody['sessionId'] = $this->sessionId;
        }

        if (!empty($data)) {
            $requestBody['data'] = (object) $data;
        }

        $postData = json_encode(
            $requestBody,
            JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_FORCE_OBJECT
        );

        echo "[调试] 请求URL: {$this->creosonUrl}\n";
        echo "[调试] {$command}.{$function} {$postData}\n";

        // 执行CURL请求
        $ch = curl_init();
        curl_setopt_array($ch, [
            CURLOPT_URL => $this->creosonUrl,
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => $postData,
            CURLOPT_HTTPHEADER => [
                'Content-Type: application/json; charset=UTF-8',
                'Content-Length: ' . strlen($postData)
            ],
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => $this->timeout,
            CURLOPT_SSL_VERIFYPEER => false,
            CURLOPT_SSL_VERIFYHOST => false
        ]);

        $response = curl_exec($ch);
        $curlError = curl_error($ch);
        curl_close($ch);

        if ($curlError) {
            throw new Exception("[CURL错误] {$curlError}");
        }

        $result = json_decode($response, true);
        if (json_last_error() !== JSON_ERROR_NONE) {
            throw new Exception("[JSON解析错误] 响应: {$response} | 错误: " . json_last_error_msg());
        }

        if (isset($result['status']['error']) && $result['status']['error'] === true) {
            $msg = isset($result['status']['message']) ? $result['status']['message'] : '未知错误';
            if ($msg == 'No session found') {
                throw new Exception("[会话未就绪] {$msg}", 1001);
            }
            throw new Exception("[Creoson错误] {$msg}");
        }

        // 保存connect返回的sessionId
        if ($command == 'connection' && $function == 'connect' && isset($result['sessionId'])) {
            $this->sessionId = $result['sessionId'];
            echo "[会话] 获取到官方SessionID: {$this->sessionId}\n";
        }

        return $result;
    }

    public function startCreo($config)
    {
        echo "【1/6】发送Creo启动命令...\n";
        $this->creosonPost('connection', 'start_creo', $config);
        echo "【1/6】Creo启动命令发送完成！\n";
    }

    public function connectAndCheckReady()
    {
        echo "【2/6】建立Creoson会话...\n";
        $this->creosonPost('connection', 'connect');
        echo "【2/6】检测Creo会话就绪状态...\n";

        $checkCount = 0;
        while ($checkCount < $this->maxReadyChecks) {
            try {
                $absDir = realpath('D:\\mydoc\\Creoson_test');
                $this->creosonPost('creo', 'cd', ['dirname' => $absDir]);
                echo "[会话] Creo实例已就绪！\n";
                echo "【2/6】会话验证成功！\n";
                return;
            } catch (Exception $e) {
                if ($e->getCode() == 1001) {
                    $checkCount++;
                    if ($checkCount >= $this->maxReadyChecks) {
                        throw new Exception("Creo会话超时未就绪（已检测{$this->maxReadyChecks}次）");
                    }
                    echo "[会话] Creo未就绪（第{$checkCount}次检测），{$this->checkInterval}秒后重试...\n";
                    sleep($this->checkInterval);
                } else {
                    throw $e;
                }
            }
        }
    }

    public function creoCd($dirName)
    {
        echo "【3/6】切换Creo工作目录到: {$dirName}\n";
        $absDir = realpath($dirName);
        if (!$absDir || !is_dir($absDir)) {
            throw new Exception("目录不存在或无效: {$dirName}（绝对路径: {$absDir}）");
        }
        $this->creosonPost('creo', 'cd', [
            'dirname' => $absDir
        ]);
        echo "【3/6】工作目录切换成功！\n";
    }

    public function fileOpen($file, $generic = "", $display = true, $activate = true)
    {
        echo "【4/6】打开Creo文件: {$file}\n";
        $fileName = basename($file); 
        $absFile = realpath("D:\\mydoc\\Creoson_test\\" . $fileName);

        if (!$absFile || !file_exists($absFile)) {
            throw new Exception("文件不存在或无效: {$file}（完整路径: {$absFile}）");
        }

        $params = [
            'file' => $fileName,
            'display' => $display,
            'activate' => $activate
        ];
        // generic字段可选，非空时添加
        if (!empty($generic)) {
            $params['generic'] = $generic;
        }

        $this->creosonPost('file', 'open', $params);
        echo "【4/6】文件打开成功！\n";
    }

    public function parameterSet($name, $value, $type = 'STRING')
    {
        echo "【5/6】设置参数 {$name} = {$value}（类型: {$type}）\n";
        $this->creosonPost('parameter', 'set', [
            'name' => $name,
            'type' => $type,
            'value' => $value,
            'no_create' => false,
            'designate' => true
        ]);
        echo "【5/6】参数设置成功！\n";
    }

    public function fileSave($file)
    {
        echo "【6/6】保存Creo文件: {$file}\n";
        $fileName = basename($file);
        $absFile = realpath("D:\\mydoc\\Creoson_test\\" . $fileName);
        if (!$absFile) {
            throw new Exception("文件路径无效: {$file}（完整路径: {$absFile}）");
        }
        $this->creosonPost('file', 'save', [
            'file' => $fileName
        ]);
        echo "【6/6】文件保存成功！\n";
    }
}

try {
    $client = new CreosonClient();
    $creoConfig = [
        'start_dir' => 'D:\\mydoc\\Creoson_test',
        'start_command' => 'nitro_proe_remote.bat',
        'retries' => 5,
        'use_desktop' => false
    ];

    // 执行流程
    $client->startCreo($creoConfig);
    $client->connectAndCheckReady();
    $client->creoCd('D:\\mydoc\\Creoson_test');
    $client->fileOpen("fin.prt", "fin");
    $client->parameterSet("test", "PHP调用CREOSON添加的参数", "STRING");
    $client->fileSave("fin.prt");

    echo "\n===== 全流程执行完成！=====\n";

} catch (Exception $e) {
    echo "\n===== 执行失败 =====\n";
    echo "错误详情: " . $e->getMessage() . "\n";
    echo "====================\n";
    exit(1);
}
?>