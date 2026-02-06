#!/bin/bash
set -euo pipefail

# ===================== 全局配置 =====================
CREOSON_URL="http://localhost:9056/creoson"
TIMEOUT=60
SESSION_ID=""
DEBUG=true

# ===================== 核心工具函数 =====================
# 错误退出函数
error_exit() {
    local msg="$1"
    local code="${2:-1}"
    echo -e "\n===== 执行失败 ====="
    echo "错误详情: $msg"
    echo "===================="
    exit "$code"
}

# JSON 格式化（屏蔽jq解析错误，只输出内容）
json_format() {
    # 直接输出，不调用jq，彻底避免解析报错
    cat
}

# 纯格式校验（无任何外部命令调用）
validate_windows_path() {
    local path="$1"
    local path_type="$2"
    # 仅检查路径是否以 盘符:\ 开头，无外部命令
    if [[ ! "$path" =~ ^[A-Za-z]:\\ ]]; then
        error_exit "不是有效的Windows路径: $path（路径类型: $path_type）"
    fi
    echo "$path"
}

# ===================== 核心POST方法（无jq构建，纯字符串）=====================
creoson_post() {
    local command="$1"
    local function="$2"
    local data_json="${3:-{}}"
    
    # 构建请求体（纯字符串拼接，无jq，无多余逗号）
    local request_body="{"
    request_body+="\"command\":\"$command\","
    request_body+="\"function\":\"$function\""
    
    # 添加SessionId（无多余逗号）
    if [ -n "$SESSION_ID" ]; then
        request_body+=","
        request_body+="\"sessionId\":\"$SESSION_ID\""
    fi
    
    # 添加data（无多余逗号）
    if [ "$data_json" != "{}" ]; then
        request_body+=","
        request_body+="\"data\":$data_json"
    fi
    request_body+="}"

    # 调试输出（无jq，直接打印）
    if [ "$DEBUG" = true ]; then
        echo -e "[调试] 请求URL: $CREOSON_URL"
        echo -e "[调试] $command.$function \n$(echo "$request_body" | json_format)"
    fi

    # 发送请求
    local response_content
    response_content=$(curl -s -X POST "$CREOSON_URL" \
        -H "Content-Type: application/json; charset=UTF-8" \
        -d "$request_body" \
        --max-time "$TIMEOUT" \
        --show-error \
        -w "\n%{http_code}" \
        --stderr -)

    # 分离状态码和响应体
    local http_code=$(echo "$response_content" | tail -n1)
    local response_body=$(echo "$response_content" | head -n -1)

    # HTTP错误处理
    if [ "$http_code" -lt 200 ] || [ "$http_code" -ge 300 ]; then
        error_exit "[HTTP错误] 状态码: $http_code | 响应内容: $response_body"
    fi

    # 提取SessionId（仅用字符串匹配，无jq）
    if [ "$command" = "connection" ] && [ "$function" = "connect" ]; then
        # 简单提取sessionId（兼容你的响应格式）
        SESSION_ID=$(echo "$response_body" | grep -o '"sessionId":"[^"]*"' | cut -d'"' -f4)
        if [ -n "$SESSION_ID" ]; then
            echo -e "[会话] 获取到SessionID: $SESSION_ID"
        fi
    fi

    # 检查Creoson错误（字符串匹配）
    if echo "$response_body" | grep -q '"error":true'; then
        local error_msg=$(echo "$response_body" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
        [ -z "$error_msg" ] && error_msg="未知错误"
        if [ "$error_msg" = "No session found" ]; then
            error_exit "[会话未就绪] $error_msg" 1001
        else
            error_exit "[Creoson错误] $error_msg"
        fi
    fi

    echo "$response_body"
}

# ===================== 业务方法 =====================
start_creo() {
    local config_json="$1"
    echo -e "【1/6】发送Creo启动命令..."
    creoson_post "connection" "start_creo" "$config_json"
    echo -e "【1/6】Creo启动命令发送完成！"
}

connect() {
    echo -e "【2/6】建立Creoson会话..."
    creoson_post "connection" "connect"
    echo -e "【2/6】检测会话就绪状态..."
}

creo_cd() {
    local dir_name="$1"
    echo -e "【3/6】切换Creo工作目录到: $dir_name"
    
    # 纯格式校验（无powershell）
    validate_windows_path "$dir_name" "dir"
    
    # 构建data（反斜杠正确转义）
    local esc_dir=$(echo "$dir_name" | sed 's/\\/\\\\/g')
    local data_json="{\"dirname\":\"$esc_dir\"}"
    
    creoson_post "creo" "cd" "$data_json"
    echo -e "【3/6】目录切换成功！"
}

file_open() {
    local file="$1"
    local generic="$2"
    local display="${3:-true}"
    local activate="${4:-true}"
    
    echo -e "【4/6】打开Creo文件: $file"
    
    local file_name=$(basename "$file")
    local abs_file="D:\\mydoc\\Creoson_test\\$file_name"
    validate_windows_path "$abs_file" "file"
    
    # 构建data（反斜杠转义）
    local esc_file=$(echo "$file_name" | sed 's/\\/\\\\/g')
    local generic_str=""
    [ -n "$generic" ] && generic_str=",\"generic\":\"$generic\""
    local data_json="{
        \"file\":\"$esc_file\",
        \"display\":$display,
        \"activate\":$activate
        $generic_str
    }"
    
    creoson_post "file" "open" "$data_json"
    echo -e "【4/6】文件打开成功！"
}

parameter_set() {
    local name="$1"
    local value="$2"
    local type="${3:-STRING}"
    
    echo -e "【5/6】设置参数 $name = $value（类型: $type）"
    
    local data_json="{
        \"name\":\"$name\",
        \"type\":\"$type\",
        \"value\":\"$value\",
        \"no_create\":false,
        \"designate\":true
    }"
    
    creoson_post "parameter" "set" "$data_json"
    echo -e "【5/6】参数设置成功！"
}

file_save() {
    local file="$1"
    echo -e "【6/6】保存Creo文件: $file"
    
    local file_name=$(basename "$file")
    local abs_file="D:\\mydoc\\Creoson_test\\$file_name"
    validate_windows_path "$abs_file" "file"
    
    local esc_file=$(echo "$file_name" | sed 's/\\/\\\\/g')
    local data_json="{\"file\":\"$esc_file\"}"
    
    creoson_post "file" "save" "$data_json"
    echo -e "【6/6】文件保存成功！"
}

# ===================== 主逻辑 =====================
main() {
    # 检查curl是否存在
    if ! command -v curl &> /dev/null; then
        echo "正在安装curl..."
        sudo apt update && sudo apt install curl -y || error_exit "curl安装失败"
    fi

    # Creo启动参数（反斜杠正确转义）
    local creo_config="{
        \"start_dir\":\"D:\\\\mydoc\\\\Creoson_test\",
        \"start_command\":\"nitro_proe_remote.bat\",
        \"retries\":5,
        \"use_desktop\":false
    }"

    # 执行全流程
    start_creo "$creo_config"
    connect
    creo_cd "D:\\mydoc\\Creoson_test"
    file_open "fin.prt" "fin"
    parameter_set "test" "Bash调用Creoson添加的参数" "STRING"
    file_save "fin.prt"

    echo -e "\n===== 全流程执行完成！====="
}

# 启动程序
trap 'error_exit "脚本执行错误: $?"' ERR
main