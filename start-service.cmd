@echo off
setlocal
cd /d "%~dp0"
where node.exe >nul 2>nul
if errorlevel 1 (
  echo Node.js nao encontrado. Execute install-runtime.ps1 como administrador.
  exit /b 1
)
start "" /min node.exe "%~dp0server.js"
exit /b 0
