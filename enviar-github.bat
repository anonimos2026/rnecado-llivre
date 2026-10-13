@echo off
title Enviar para o GitHub e Vercel
echo ===================================================
echo Enviando projeto atualizado para o GitHub...
echo (A Vercel fara o deploy automaticamente assim que enviar)
echo ===================================================
git push origin main
echo.
echo ===================================================
echo Concluido!
echo ===================================================
pause
