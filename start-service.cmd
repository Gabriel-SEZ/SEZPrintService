@echo off
cd /d "%~dp0"
start "" /min "%ProgramFiles%\nodejs\node.exe" "%~dp0server.js"
