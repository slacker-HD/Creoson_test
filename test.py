import creopyson
import os


current_dir = os.getcwd()

# 初始化
c = creopyson.Client()

# 启动Creo
# nitro_proe_remote.bat复制自parametric.bat，不知道CREOSON为什么默认改成这个名字
# 修改nitro_proe_remote.bat用于自定义配置
# command = "connection"
# function = "start_creo"
# data = {"start_dir": current_dir, "start_command": "nitro_proe_remote.bat", "retries": 5}
# result = c._creoson_post(command, function, data)
# 这样也行
c.start_creo(current_dir + "\\nitro_proe_remote.bat", 5, False)

c.connect()  # 这个必须得要，否则后面会提示没有sessionID

# 修改工作目录为程序所在目录
# command = "creo"
# function = "cd"
# data = {"dirname": current_dir}
# result = c._creoson_post(command, function, data)
# 这样也行
c.creo_cd(current_dir)

# 打开文件并显示
command = "file"
function = "open"
data = {"file": "fin.prt", "display": True, "activate": True}
result = c._creoson_post(command, function, data)
# 这样也行
# c.file_open("fin.prt", display=True)

# 添加或修改参数
# command = "parameter"
# function = "set"
# data = {"name": "test", "type": "STRING", "value": "测试参数值", "no_create": False, "designate": True}
# result = c._creoson_post(command, function, data)
# 这样也行
c.parameter_set("test", "测试参数值2", None, "STRING", None, True, False)

# 保存文件
# command = "file"
# function = "save"
# data = {"file": "FIN.PRT"}
# result = c._creoson_post(command, function, data)
# 这样也行
c.file_save("fin.prt")
