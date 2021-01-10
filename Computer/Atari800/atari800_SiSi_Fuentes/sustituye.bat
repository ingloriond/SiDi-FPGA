@echo off
Setlocal EnableDelayedExpansion
if "%3" == "" goto ayuda
set cadorig=%1
set cadorig=%cadorig:"=%
set cadsust=%2
set cadsust=%cadsust:"=%
for %%f in (%3) do (call :cambiar %%f)
goto fin
:cambiar
set archivo=%1
for /f "tokens=* delims=" %%i in (%archivo%) do (set ANT=%%i&echo !ANT:%cadorig%=%cadsust%! >>kk_temp.txt)
copy /y kk_temp.txt %archivo%
del /q kk_temp.txt
goto :EOF
:Ayuda
Echo Reemplaza una cadena por otra en el contenido de archivos (con comodines)
echo Utiliza un archivo temporal kk_temp.txt que no debe existir previamente
echo Formato: %0 cadorig cadsust archivos
echo Si las cadenas contienen espacios deben escribirse entrecomilladas
echo No funciona si la cadena original contiene un "="
Echo Ejemplo:
echo %0 de DE *.txt
:Fin