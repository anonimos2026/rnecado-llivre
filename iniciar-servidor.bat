@echo off
title Servidor Local - Mercado Livre
echo Iniciando servidor local...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0server.ps1"
pause
