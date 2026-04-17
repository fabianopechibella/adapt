@echo off
chcp 65001 >nul
title SETUP — SISTEMA DE PESQUISA ESAJ

echo.
echo  ====================================================
echo       CONFIGURACAO DO SISTEMA DE PESQUISA ESAJ
echo  ====================================================
echo.
echo  Este script instala tudo que e necessario para
echo  o sistema funcionar. Execute apenas uma vez.
echo.

:: Verificar Python
python --version >nul 2>&1
if errorlevel 1 (
    echo  ERRO: Python nao encontrado!
    echo.
    echo  1. Acesse: https://www.python.org/downloads/
    echo  2. Baixe a versao mais recente para Windows
    echo  3. Na instalacao, MARQUE "Add Python to PATH"
    echo  4. Reinicie este arquivo apos instalar
    echo.
    pause
    exit /b 1
)

for /f "tokens=*" %%i in ('python --version') do set PY_VER=%%i
echo  %PY_VER% encontrado!
echo.

:: Instalar dependencias
echo  Instalando dependencias Python...
echo.
pip install --upgrade pip >nul 2>&1
pip install selenium openpyxl

if errorlevel 1 (
    echo.
    echo  ERRO ao instalar dependencias!
    echo  Verifique sua conexao com a internet e tente novamente.
    echo.
    pause
    exit /b 1
)

echo.
echo  Dependencias instaladas com sucesso!
echo.

:: Criar planilhas modelo
echo  Criando planilhas modelo...
echo.
python criar_planilhas.py

echo.
echo  ====================================================
echo   SETUP CONCLUIDO!
echo.
echo   Como usar o sistema:
echo.
echo   PASSO 1:
echo     Abra "CONSULTA PROCESSOS 2026 - COPIA.xlsx"
echo     Cole os numeros de processo na coluna A
echo     (um numero por linha) e salve o arquivo.
echo.
echo   PASSO 2:
echo     Execute "START_EDGE-MANUAL_LOGIN.bat"
echo     Aguarde o Edge abrir o ESAJ e faca o login.
echo     Minimize o Edge apos logar.
echo.
echo   PASSO 3:
echo     Execute "RUM_ESAJ.bat"
echo     O sistema pesquisara todos os processos
echo     automaticamente. Nao feche a tela preta!
echo.
echo   RESULTADO:
echo     Abra "RESULTADOS_CONSULTA.xlsx" para ver
echo     todos os dados extraidos do ESAJ.
echo  ====================================================
echo.
pause
