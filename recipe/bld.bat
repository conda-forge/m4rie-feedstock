@echo off
setlocal EnableDelayedExpansion

:: m2-bash is installed into the build environment via meta.yaml requirements
:: It is available at %BUILD_PREFIX%\Library\usr\bin\bash.exe
set "BASH=%BUILD_PREFIX%\Library\usr\bin\bash.exe"

"%BASH%" "%RECIPE_DIR%/build.sh"
if %ERRORLEVEL% neq 0 exit 1
