@echo off
rem Cidade ICMC no simulador do professor (Windows).
rem Esta pasta tem que estar DENTRO da pasta "Simulador" do pacote
rem Simulador_Windows_Tudo_Pronto_Facil do professor (ver README.md).
rem Na janela do simulador: Home liga a execucao, depois Enter.
cd /d "%~dp0"
if not exist "..\Versao_05_2013\32_bits\simulador.exe" (
  echo Nao achei ..\Versao_05_2013\32_bits\simulador.exe
  echo Coloque esta pasta dentro da pasta "Simulador" do pacote do professor.
  pause
  exit /b 1
)
start "" "..\Versao_05_2013\32_bits\simulador.exe" jogo.mif charmap.mif
