// 日志输出函数（带时间戳）
function log(msg) {
  const el = document.getElementById('log');
  const time = new Date().toLocaleTimeString();
  el.textContent += `[${time}] ${msg}\n`;
  el.scrollTop = el.scrollHeight; // 自动滚动到底部
  console.log(`[${time}] ${msg}`);
}

// 初始化清空日志按钮
document.getElementById('btnClearLog').addEventListener('click', function () {
  document.getElementById('log').textContent = '';
  log('日志已清空');
});

// 设置Creoson URL并适配AJAX配置
function setCreosonUrl(url) {
  if (creo && creo.ajax) {
    creo.ajax.url = url;
    creo.ajax.type = 'post';
    creo.ajax.dataType = 'json';

    // 重写AJAX请求逻辑，兼容浏览器跨域+SessionID自动维护
    if (!creo.ajax.rewritten) {
      creo.ajax.request = function (dataObj) {
        return new Promise(function (resolve, reject) {
          // 自动携带SessionID
          if (creo.ajax.sessionId !== -1 && typeof creo.ajax.sessionId !== 'undefined') {
            dataObj.sessionId = creo.ajax.sessionId;
          }

          const xhr = new XMLHttpRequest();
          const postData = JSON.stringify(dataObj);

          xhr.open('POST', creo.ajax.url, true);
          xhr.setRequestHeader('Content-Type', 'application/json');
          xhr.setRequestHeader('Content-Length', postData.length);

          xhr.onload = function () {
            if (xhr.status >= 200 && xhr.status < 300) {
              try {
                const response = JSON.parse(xhr.responseText);
                // 连接成功时保存SessionID
                if (dataObj.command === 'connection' && dataObj.function === 'connect' && response.sessionId) {
                  creo.ajax.sessionId = response.sessionId;
                  log(`自动设置SessionID: ${response.sessionId}`);
                }
                // 处理Creoson自身错误
                if (response.status && response.status.error) {
                  reject(new Error(response.status.message || 'Creoson操作失败'));
                } else {
                  resolve(response);
                }
              } catch (e) {
                reject(new Error(`解析响应失败: ${e.message}`));
              }
            } else {
              reject(new Error(`请求失败: ${xhr.status} ${xhr.statusText}`));
            }
          };

          xhr.onerror = function () {
            reject(new Error(`网络错误: 无法连接到 ${creo.ajax.url} (请确认Creoson Server已启动)`));
          };

          xhr.send(postData);
        });
      };
      creo.ajax.rewritten = true; // 标记已重写，避免重复覆盖
    }
    log(`已设置Creoson URL: ${url}`);
  }
}

// 监听Creoson URL输入框变化
document.getElementById('creosonUrl').addEventListener('change', function (e) {
  setCreosonUrl(e.target.value);
});

// 启动Creo函数
async function startCreo(startDir, startCmd) {
  log(`开始启动Creo - 工作目录: ${startDir}, 启动命令: ${startCmd}`);
  const sess = new creo.ConnectionObj({
    start_dir: startDir,
    start_command: startCmd,
    retries: 5,
    use_desktop: false
  });

  try {
    const resp = await sess.start_creo();
    log(`✅ Creo启动成功: ${JSON.stringify(resp)}`);
    return sess;
  } catch (err) {
    log(`⚠️ Creo启动失败/已启动: ${err.message || JSON.stringify(err)}`);
    return sess; // 即使启动失败也返回会话对象，用于后续连接
  }
}

// 连接Creo函数
async function connectCreo(sess) {
  log('开始连接Creo...');
  const resp = await sess.connect();
  log(`✅ Creo连接成功: ${JSON.stringify(resp)}`);
  return resp;
}

// 切换工作目录
async function changeDir(startDir) {
  log(`切换工作目录到: ${startDir}`);
  const c = new creo.CreoObj({ dirname: startDir });
  const cdResp = await c.cd();
  log(`✅ 目录切换成功: ${JSON.stringify(cdResp)}`);
  return cdResp;
}

// 打开文件
async function openFile(fileName) {
  log(`打开目标文件: ${fileName}`);
  const f = new creo.FileObj({
    file: fileName,
    display: true,
    activate: true
  });
  const openResp = await f.open();
  log(`✅ 文件打开成功: ${JSON.stringify(openResp)}`);
  return openResp;
}

// 设置参数
async function setParameter(paramName, paramValue) {
  log(`设置参数: ${paramName} = ${paramValue} (类型: STRING)`);
  const p = new creo.ParameterObj({
    name: paramName,
    value: paramValue,
    type: 'STRING',
    designate: true,
    no_create: false
  });
  const pResp = await p.set();
  log(`✅ 参数设置成功: ${JSON.stringify(pResp)}`);
  return pResp;
}

// 保存文件
async function saveFile(fileName) {
  log(`保存文件: ${fileName}`);
  const s = new creo.FileObj({ file: fileName });
  const saveResp = await s.save();
  log(`✅ 文件保存成功: ${JSON.stringify(saveResp)}`);
  return saveResp;
}

// 完整执行序列（一键执行所有操作）
async function runAllOperations() {
  try {
    const creosonUrl = document.getElementById('creosonUrl').value.trim();
    const startDir = document.getElementById('startDir').value.trim();
    const startCmd = document.getElementById('startCmd').value.trim();
    const fileName = document.getElementById('fileName').value.trim();
    const paramName = document.getElementById('paramName').value.trim();
    const paramValue = document.getElementById('paramValue').value.trim();

    // 校验必填项
    if (!paramName) {
      throw new Error('参数名称不能为空，请填写后重试');
    }
    if (!paramValue) {
      throw new Error('参数值不能为空，请填写后重试');
    }

    // 初始化Creoson URL
    setCreosonUrl(creosonUrl);

    log('====================================================');
    log('🚀 开始执行Creoson自动化全流程');
    log('====================================================');

    // 1. 启动Creo
    const sess = await startCreo(startDir, startCmd);

    // 2. 连接Creo
    await connectCreo(sess);

    // 3. 切换工作目录
    await changeDir(startDir);

    // 4. 打开目标文件
    await openFile(fileName);

    // 5. 设置参数（使用页面配置的参数名和值）
    await setParameter(paramName, paramValue);

    // 6. 保存文件
    await saveFile(fileName);

    log('====================================================');
    log('🎉 所有操作执行完成！');
    log('====================================================');
  } catch (err) {
    log('====================================================');
    log(`❌ 流程执行出错: ${err.message || JSON.stringify(err)}`);
    log('====================================================');
    // 排查建议
    log(`
排查建议：
1. 确认Creoson Server已启动（端口9056）：执行 netstat -ano | findstr 9056
2. 确认${document.getElementById('startDir').value} 目录下有 ${document.getElementById('fileName').value} 和 ${document.getElementById('startCmd').value}
3. 确认Creoson URL填写正确（当前: ${document.getElementById('creosonUrl').value}）
4. 若报跨域错误，请启动Creoson CORS代理后修改URL为 http://localhost:8080/creoson`);
  }
}

// 绑定「执行全部操作」按钮事件
document.getElementById('btnRunAll').addEventListener('click', runAllOperations);

// 页面加载完成后初始化
window.onload = function () {
  // 初始化Creoson URL
  setCreosonUrl(document.getElementById('creosonUrl').value);
  log('页面初始化完成，点击「执行全部操作」开始流程');
  log(`默认参数配置: ${document.getElementById('paramName').value} = ${document.getElementById('paramValue').value}`);
};