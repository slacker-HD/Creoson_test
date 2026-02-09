# CREOSON的测试代码

## CREOSON的环境配置

**首先确保JLINK已正确安装**。在官网下载 `CREOSON Server`,地址在<a href="https://github.com/SimplifiedLogic/creoson/releases" target="_blank">https://github.com/SimplifiedLogic/creoson/releases</a>。下载解压后，运行目录下`CreosonSetup.exe`,在 `Step 1:`栏输入正确的CREO安装目录，点击 `Start CREOSON`，就可以启动CREOSON服务。如果服务正常运行，以后可以直接运行`creoson_run.bat`直接启动服务。

## test.py

- Python测试代码，打开当前目录下fin.prt添加参数后保存。

## test.js

- Nodejs测试代码，打开当前目录下fin.prt添加参数后保存。
- creoson_js的文件复制自`CREOSON Server`  `\web\assets\creoson_stuff\creoson_js`，我修改了一点，加入了模块导出。

## 网页JavaScript测试文件夹

- Html+Javascript测试代码，打开当前目录下fin.prt添加参数后保存。
- 注意要把`网页JavaScript测试`下所有文件复制到`CREOSON Server`  `\web`文件夹下，访问`http://localhost:9056/test.html`实现功能，端口由`CREOSON Server`确定，否则会有跨域权限的问题导致网页功能不正常无法访问本地文件。

以下代码是使用不同的语言通过HTTP POST请求实现打开当前目录下fin.prt添加参数后保存。

## test2.js

- Nodejs测试代码，打开当前目录下fin.prt添加参数后保存。

## test.php

- PHP测试代码，打开当前目录下fin.prt添加参数后保存。

## test.bat

- 批处理测试代码，打开当前目录下fin.prt添加参数后保存。

## test.ps1

- PowerShell测试代码，打开当前目录下fin.prt添加参数后保存。

## test.vbs

- vbs测试代码，打开当前目录下fin.prt添加参数后保存。

## test.java

- java测试代码，打开当前目录下fin.prt添加参数后保存。

## test.cs

- CSharp测试代码，打开当前目录下fin.prt添加参数后保存。

## wsl测试文件夹

- test.sh，bash脚本，复制到wsl下面chmod +x后运行，实现wsl远程打开windows下目录下fin.prt添加参数后保存。
- Creoson9056-开启.bat，开启端口9056，这样WSL可以访问CREOSON服务。
- Creoson9056-关闭.bat，关闭端口9056，**不用的时候一定要记得关闭**。
