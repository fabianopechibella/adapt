@echo off
chcp 65001 >nul
title PESQUISA AUTOMATICA — ESAJ

echo.
echo  ====================================================
echo       SISTEMA DE PESQUISA ESAJ  —  PASSO 2/2
echo  ====================================================
echo.

:: Verificar se Python esta instalado
python --version >nul 2>&1
if errorlevel 1 (
    echo  ERRO: Python nao encontrado!
    echo.
    echo  Execute setup.bat primeiro para instalar o Python
    echo  e as dependencias necessarias.
    echo.
    pause
    exit /b 1
)

:: Verificar se o script principal existe
if not exist "esaj_pesquisa.py" (
    echo  ERRO: Arquivo esaj_pesquisa.py nao encontrado!
    echo  Certifique-se de que todos os arquivos estao na
    echo  mesma pasta (AUTOMACAO).
    echo.
    pause
    exit /b 1
)

:: Verificar se a planilha de entrada existe
if not exist "CONSULTA PROCESSOS 2026 - COPIA.xlsx" (
    echo  AVISO: Planilha "CONSULTA PROCESSOS 2026 - COPIA.xlsx"
    echo  nao encontrada nesta pasta.
    echo.
    echo  Execute criar_planilhas.bat para criar o modelo,
    echo  ou copie a planilha para esta pasta.
    echo.
    pause
    exit /b 1
)

echo  Iniciando pesquisa automatica...
echo  Nao feche esta janela durante a execucao!
echo.
echo  ====================================================
echo.

python esaj_pesquisa.py

echo.
echo  ====================================================
echo   Pesquisa finalizada!
echo   Abra RESULTADOS_CONSULTA.xlsx para ver os dados.
echo  ====================================================
echo.
pause
