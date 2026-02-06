@echo off
powershell -Command "Set-NetFirewallRule -DisplayName 'WSL2访问Creoson9056' -Enabled False"
echo Creoson9056端口防火墙规则已关闭
pause