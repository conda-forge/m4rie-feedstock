@echo off
setlocal EnableDelayedExpansion

:: MSYS2 bash requires /tmp to exist or it may hang at startup
if not exist C:\tmp mkdir C:\tmp
set "TMP=C:\tmp"
set "TEMP=C:\tmp"

:: Find the MinGW-w64 cross-compiler installed in the conda base environment.
:: setup-miniconda sets CONDA; conda_hook.bat sets _CONDA_ROOT.
if defined CONDA (
    set "MINGW_BIN=%CONDA%\Library\mingw-w64\bin"
) else if defined _CONDA_ROOT (
    set "MINGW_BIN=%_CONDA_ROOT%\Library\mingw-w64\bin"
) else (
    set "MINGW_BIN="
)

if defined MINGW_BIN (
    if exist "!MINGW_BIN!\x86_64-w64-mingw32-gcc.exe" (
        set "PATH=!MINGW_BIN!;%PATH%"
        echo Added MinGW to PATH: !MINGW_BIN!
    ) else (
        echo WARNING: x86_64-w64-mingw32-gcc.exe not found at !MINGW_BIN!
    )
) else (
    echo WARNING: could not locate conda base env for MinGW lookup
)

:: m2-bash is installed into the build environment via meta.yaml requirements
:: It is available at %BUILD_PREFIX%\Library\usr\bin\bash.exe
set "BASH=%BUILD_PREFIX%\Library\usr\bin\bash.exe"

:: --norc --noprofile: skip bash init files that may block in MSYS2 env
"%BASH%" --norc --noprofile "%RECIPE_DIR%/build.sh"
if %ERRORLEVEL% neq 0 exit 1
