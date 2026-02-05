import requests
import json
import os
import sys
from pathlib import Path
import urllib3

# 禁用SSL警告（与JS中的 rejectUnauthorized: false 等效）
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


class CreosonClient:
    def __init__(self):
        self.creoson_url = 'http://localhost:9056/creoson'
        self.timeout = 60 
        self.session_id = ''

    def creoson_post(self, command: str, function_name: str, data: dict = None) -> dict:
        if data is None:
            data = {}

        request_body = {
            "command": command,
            "function": function_name
        }

        if self.session_id:
            request_body["sessionId"] = self.session_id

        if data:
            request_body["data"] = data

        post_data = json.dumps(request_body, ensure_ascii=False)

        print(f"[调试] 请求URL: {self.creoson_url}")
        print(f"[调试] {command}.{function_name} {post_data}")

        try:
            response = requests.post(
                self.creoson_url,
                data=post_data.encode('utf-8'),
                timeout=self.timeout,
                headers={
                    'Content-Type': 'application/json; charset=UTF-8',
                    'Content-Length': str(len(post_data.encode('utf-8')))
                },
                verify=False
            )

            response.raise_for_status()
            result = response.json()

            if not isinstance(result, dict):
                raise Exception(f"[JSON解析错误] 响应: {response.text} | 错误: 无效的JSON格式")

            status = result.get('status', {})
            if status.get('error') is True:
                msg = status.get('message', '未知错误')
                if msg == 'No session found':
                    error = Exception(f"[会话未就绪] {msg}")
                    error.code = 1001
                    raise error
                raise Exception(f"[Creoson错误] {msg}")

            if command == 'connection' and function_name == 'connect' and result.get('sessionId'):
                self.session_id = result['sessionId']
                print(f"[会话] 获取到官方SessionID: {self.session_id}")

            return result

        except requests.exceptions.Timeout:
            raise Exception(f"[请求超时] 请求超时（{self.timeout}秒）")
        except requests.exceptions.HTTPError as e:
            raise Exception(f"[HTTP错误] 状态码: {e.response.status_code} | 响应: {e.response.text}")
        except requests.exceptions.ConnectionError as e:
            raise Exception(f"[CURL错误] 无法连接到服务器: {str(e)}")
        except json.JSONDecodeError:
            raise Exception(f"[JSON解析错误] 响应: {response.text} | 错误: 无效的JSON格式")
        except Exception:
            raise

    def start_creo(self, config: dict):
        print("【1/6】发送Creo启动命令...")
        self.creoson_post('connection', 'start_creo', config)
        print("【1/6】Creo启动命令发送完成！")

    def connect(self):
        print("【2/6】建立Creoson会话...")
        self.creoson_post('connection', 'connect')
        print("【2/6】检测Creo会话就绪状态...")

    def creo_cd(self, dir_name: str):
        print(f"【3/6】切换Creo工作目录到: {dir_name}")
        abs_dir = Path(dir_name).resolve()

        if not abs_dir.exists() or not abs_dir.is_dir():
            raise Exception(f"目录不存在或无效: {dir_name}（绝对路径: {abs_dir}）")

        self.creoson_post('creo', 'cd', {
            "dirname": str(abs_dir)
        })
        print("【3/6】工作目录切换成功！")

    def file_open(self, file: str, generic: str = "", display: bool = True, activate: bool = True):
        print(f"【4/6】打开Creo文件: {file}")
        file_name = Path(file).name
        abs_file = Path("D:\\mydoc\\Creoson_test\\") / file_name

        if not abs_file.exists() or not abs_file.is_file():
            raise Exception(f"文件不存在或无效: {file}（完整路径: {abs_file}）")

        params = {
            "file": file_name,
            "display": display,
            "activate": activate
        }

        if generic:
            params["generic"] = generic

        self.creoson_post('file', 'open', params)
        print("【4/6】文件打开成功！")

    def parameter_set(self, name: str, value: str, type_: str = 'STRING'):
        print(f"【5/6】设置参数 {name} = {value}（类型: {type_}）")
        self.creoson_post('parameter', 'set', {
            "name": name,
            "type": type_,
            "value": value,
            "no_create": False,
            "designate": True
        })
        print("【5/6】参数设置成功！")

    def file_save(self, file: str):
        print(f"【6/6】保存Creo文件: {file}")
        file_name = Path(file).name
        abs_file = Path("D:\\mydoc\\Creoson_test\\") / file_name

        if not abs_file.exists():
            raise Exception(f"文件路径无效: {file}（完整路径: {abs_file}）")

        self.creoson_post('file', 'save', {
            "file": file_name
        })
        print("【6/6】文件保存成功！")


def main():
    try:
        client = CreosonClient()
        creo_config = {
            "start_dir": 'D:\\mydoc\\Creoson_test',
            "start_command": 'nitro_proe_remote.bat',
            "retries": 5,
            "use_desktop": False
        }

        client.start_creo(creo_config)
        client.connect()
        client.creo_cd('D:\\mydoc\\Creoson_test')
        client.file_open("fin.prt", "fin")
        client.parameter_set("test", "PYthon调用CREOSON添加的参数", "STRING")
        client.file_save("fin.prt")

        print("\n===== 全流程执行完成！=====")
    except Exception as error:
        print("\n===== 执行失败 =====")
        print(f"错误详情: {error}")
        if hasattr(error, 'code'):
            print(f"错误代码: {error.code}")
        sys.exit(1)


if __name__ == "__main__":
    main()