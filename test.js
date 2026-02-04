
// 按需载入对应的模块
// 注意官方提供的文件没有导出，需要在每个模块最后添加：
// if (typeof module !== 'undefined' && module.exports) {
//     module.exports = creo;
// } 
const creo = require('./creoson_js/creoson_connection.js');
const creo_creo = require('./creoson_js/creoson_creo.js');
const creo_file = require('./creoson_js/creoson_file.js');
const creo_parameter = require('./creoson_js/creoson_parameter.js');
const commonAjax = require('./creoson_js/common_creoson_ajax.js');

function initCreosonAjax(creoCore, ajaxTool, modules) {
    // 1. 校验并为核心对象注入AJAX方法
    creoCore.ajax = ajaxTool.ajax;
    // 2. 为每个功能模块注入相同的AJAX方法（保证请求逻辑统一）
    if (Array.isArray(modules)) {
        modules.forEach(function (mod) {
            // 安全校验：确保模块是有效对象
            if (mod && typeof mod === 'object') {
                mod.ajax = creoCore.ajax;
            }
        });
    }
}
initCreosonAjax(
    creo,                  // Creoson核心对象
    commonAjax,            // AJAX工具对象
    [creo_creo, creo_file, creo_parameter]  // 需要初始化的功能模块列表
);


// 创建对象，之后可以connect或start_creo
let sessObj = new creo.ConnectionObj({
    start_dir: __dirname,
    start_command: 'nitro_proe_remote.bat',
    retries: 5,
    use_desktop: false
});

// 创建会话，异步机制一步一步then过去，不然会出问题
// connect -> cd -> open file -> set parameter -> save file；与Python的代码一致
sessObj.start_creo()
    .then(function (resp) {
        console.log('start_creo succeeded. Response:');
        console.log(JSON.stringify(resp, null, 2));
        return sessObj.connect();
    })
    .then(function (resp) {
        console.log('Connected. Response:');
        console.log(JSON.stringify(resp, null, 2));
        let c = new creo_creo.CreoObj({ dirname: __dirname });
        return c.cd();
    })
    .then(function (resp) {
        console.log('creo_cd succeeded. Response:');
        console.log(JSON.stringify(resp, null, 2));
        let f = new creo_file.FileObj({ file: 'fin.prt', display: true, activate: true });
        return f.open();
    })
    .then(function (resp) {
        console.log('file_open succeeded. Response:');
        console.log(JSON.stringify(resp, null, 2));
        let p = new creo_parameter.ParameterObj({ name: 'Nodejst', value: 'Nodejs测试参数值3', type: 'STRING', designate: true, no_create: false });
        return p.set();
    })
    .then(function (resp) {
        console.log('parameter_set succeeded. Response:');
        console.log(JSON.stringify(resp, null, 2));
        let s = new creo_file.FileObj({ file: 'fin.prt' });
        return s.save();
    })
    .catch(function (err) {
        console.error('Error in sequence:');
        console.error(err);
    });