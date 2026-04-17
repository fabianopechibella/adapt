@echo off
chcp 65001 >nul
title INICIAR EDGE — LOGIN ESAJ

echo.
echo  ====================================================
echo       SISTEMA DE PESQUISA ESAJ  —  PASSO 1/2
echo  ====================================================
echo.
echo  Este programa vai abrir o Edge no site do ESAJ.
echo  Faca o LOGIN normalmente e minimize o Edge.
echo  Depois execute RUM_ESAJ.bat para iniciar as pesquisas.
echo.
echo  ====================================================
echo.
echo  Localizando Microsoft Edge...

set EDGE=""

if exist "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" (
    set EDGE="C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
    goto :encontrou
)
if exist "C:\Program Files\Microsoft\Edge\Application\msedge.exe" (
    set EDGE="C:\Program Files\Microsoft\Edge\Application\msedge.exe"
    goto :encontrou
)

echo.
echo  ERRO: Microsoft Edge nao encontrado no computador.
echo  Verifique se o Edge esta instalado e tente novamente.
echo.
pause
exit /b 1

:encontrou
echo  Edge encontrado!
echo.

:: Criar pasta de perfil dedicada (isolada para nao afetar perfil pessoal)
if not exist "%TEMP%\EdgeESAJ_Debug" mkdir "%TEMP%\EdgeESAJ_Debug"

echo  Abrindo Edge com modo de depuracao (porta 9222)...
echo.

start "" %EDGE% ^
    --remote-debugging-port=9222 ^
    --user-data-dir="%TEMP%\EdgeESAJ_Debug" ^
    --no-first-run ^
    --disable-extensions ^
    "https://esaj.tjsp.jus.br/sajcas/login"

echo  Edge aberto!
echo.
echo  ====================================================
echo   INSTRUCOES:
echo   1. Aguarde o Edge abrir o ESAJ
echo   2. Clique em "Identificar-se" e faca o login
echo   3. Apos logado, MINIMIZE o Edge
echo   4. Execute RUM_ESAJ.bat para iniciar as pesquisas
echo  ====================================================
echo.
echo  (Esta janela pode ser fechada apos o Edge abrir)
echo.
pause
