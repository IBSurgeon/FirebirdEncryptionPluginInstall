@echo off

powershell -ExecutionPolicy Bypass -File %~dp0\inst-crypt-plugin.ps1 %*
pause
