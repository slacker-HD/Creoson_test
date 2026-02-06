@echo off
powershell -Command "Set-NetFirewallRule -DisplayName 'WSL2访问Creoson9056' -Enabled True"
echo Creoson9056端口防火墙规则已开启
pause