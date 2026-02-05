const axios = require('axios');
const fs = require('fs');
const path = require('path');

// 配置axios默认参数
axios.defaults.timeout = 60000; // 60秒超时
axios.defaults.headers.post['Content-Type'] = 'application/json; charset=UTF-8';

class CreosonClient {
    constructor() {
        this.creosonUrl = 'http://localhost:9056/creoson';
        this.timeout = 60000;
        this.sessionId = '';
    }

    async creosonPost(command, functionName, data = {}) {
        const requestBody = {
            command: command,
            function: functionName
        };

        if (this.sessionId) {
            requestBody.sessionId = this.sessionId;
        }

        if (Object.keys(data).length > 0) {
            requestBody.data = data;
        }

        const postData = JSON.stringify(requestBody);

        console.log(`[调试] 请求URL: ${this.creosonUrl}`);
        console.log(`[调试] ${command}.${functionName} ${postData}`);

        try {
            const response = await axios.post(this.creosonUrl, postData, {
                timeout: this.timeout,
                headers: {
                    'Content-Length': Buffer.byteLength(postData, 'utf8')
                },
                httpsAgent: new (require('https').Agent)({
                    rejectUnauthorized: false
                })
            });

            const result = response.data;

            if (typeof result !== 'object') {
                throw new Error(`[JSON解析错误] 响应: ${JSON.stringify(response.data)} | 错误: 无效的JSON格式`);
            }

            if (result.status?.error === true) {
                const msg = result.status.message || '未知错误';
                if (msg === 'No session found') {
                    const error = new Error(`[会话未就绪] ${msg}`);
                    error.code = 1001;
                    throw error;
                }
                throw new Error(`[Creoson错误] ${msg}`);
            }

            if (command === 'connection' && functionName === 'connect' && result.sessionId) {
                this.sessionId = result.sessionId;
                console.log(`[会话] 获取到官方SessionID: ${this.sessionId}`);
            }

            return result;
        } catch (error) {
            if (error.code === 'ECONNABORTED') {
                throw new Error(`[请求超时] 请求超时（${this.timeout / 1000}秒）`);
            } else if (error.response) {
                throw new Error(`[HTTP错误] 状态码: ${error.response.status} | 响应: ${JSON.stringify(error.response.data)}`);
            } else if (error.request) {
                throw new Error(`[CURL错误] 无法连接到服务器: ${error.message}`);
            } else {
                throw error;
            }
        }
    }

    /**
     * 启动Creo
     */
    async startCreo(config) {
        console.log("【1/6】发送Creo启动命令...");
        await this.creosonPost('connection', 'start_creo', config);
        console.log("【1/6】Creo启动命令发送完成！");
    }

    /**
     * 建立Creoson会话
     */
    async connect() {
        console.log("【2/6】建立Creoson会话...");
        await this.creosonPost('connection', 'connect');
        console.log("【2/6】检测Creo会话就绪状态...");
    }

    /**
     * 切换Creo工作目录
     */
    async creoCd(dirName) {
        console.log(`【3/6】切换Creo工作目录到: ${dirName}`);
        const absDir = path.resolve(dirName);

        // 检查目录是否存在
        if (!fs.existsSync(absDir) || !fs.statSync(absDir).isDirectory()) {
            throw new Error(`目录不存在或无效: ${dirName}（绝对路径: ${absDir}）`);
        }

        await this.creosonPost('creo', 'cd', {
            dirname: absDir
        });
        console.log("【3/6】工作目录切换成功！");
    }

    /**
     * 打开Creo文件
     */
    async fileOpen(file, generic = "", display = true, activate = true) {
        console.log(`【4/6】打开Creo文件: ${file}`);
        const fileName = path.basename(file);
        const absFile = path.resolve("D:\\mydoc\\Creoson_test\\", fileName);

        if (!fs.existsSync(absFile) || !fs.statSync(absFile).isFile()) {
            throw new Error(`文件不存在或无效: ${file}（完整路径: ${absFile}）`);
        }

        const params = {
            file: fileName,
            display: display,
            activate: activate
        };

        if (generic) {
            params.generic = generic;
        }

        await this.creosonPost('file', 'open', params);
        console.log("【4/6】文件打开成功！");
    }

    /**
     * 设置Creo参数
     */
    async parameterSet(name, value, type = 'STRING') {
        console.log(`【5/6】设置参数 ${name} = ${value}（类型: ${type}）`);
        await this.creosonPost('parameter', 'set', {
            name: name,
            type: type,
            value: value,
            no_create: false,
            designate: true
        });
        console.log("【5/6】参数设置成功！");
    }

    /**
     * 保存Creo文件
     */
    async fileSave(file) {
        console.log(`【6/6】保存Creo文件: ${file}`);
        const fileName = path.basename(file);
        const absFile = path.resolve("D:\\mydoc\\Creoson_test\\", fileName);

        if (!fs.existsSync(absFile)) {
            throw new Error(`文件路径无效: ${file}（完整路径: ${absFile}）`);
        }

        await this.creosonPost('file', 'save', {
            file: fileName
        });
        console.log("【6/6】文件保存成功！");
    }
}

(async () => {
    try {
        const client = new CreosonClient();
        const creoConfig = {
            start_dir: 'D:\\mydoc\\Creoson_test',
            start_command: 'nitro_proe_remote.bat',
            retries: 5,
            use_desktop: false
        };

        await client.startCreo(creoConfig);
        await client.connect();
        await client.creoCd('D:\\mydoc\\Creoson_test');
        await client.fileOpen("fin.prt", "fin");
        await client.parameterSet("test", "PHP调用CREOSON添加的参数", "STRING");
        await client.fileSave("fin.prt");

        console.log("\n===== 全流程执行完成！=====");
    } catch (error) {
        console.log("\n===== 执行失败 =====");
        console.log(`错误详情: ${error.message}`);
        if (error.code) {
            console.log(`错误代码: ${error.code}`);
        }
        process.exit(1);
    }
})();