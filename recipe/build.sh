#!/bin/bash
set -euo pipefail

if [[ "${target_platform}" == win* ]]; then
    # MSYS2 bash may hang if /tmp doesn't exist
    mkdir -p /tmp

    # Use POSIX-style path (starts with /) — autoconf accepts it as absolute.
    INSTALL_PREFIX=$(python -c "
import os
p = os.environ['LIBRARY_PREFIX'].replace('\\\\', '/')
drive, rest = p.split(':', 1)
print('/' + drive.lower() + rest)
")
    echo "INSTALL_PREFIX=${INSTALL_PREFIX}"

    # Locate the MinGW-w64 cross-compiler
    if command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1; then
        export CC=x86_64-w64-mingw32-gcc
        export AR=x86_64-w64-mingw32-ar
        export RANLIB=x86_64-w64-mingw32-ranlib
        export STRIP=x86_64-w64-mingw32-strip
        echo "Using MinGW cross-compiler: $(which x86_64-w64-mingw32-gcc)"
    else
        echo "WARNING: x86_64-w64-mingw32-gcc not found, falling back to gcc"
        export CC=gcc
    fi

    # Override CFLAGS completely — conda-build sets MSVC flags when vs2022_win-64
    # is in build requirements; those flags are incompatible with MinGW.
    export CFLAGS="-O2 -g"
    export CPPFLAGS="-I${INSTALL_PREFIX}/include"
    export LDFLAGS="-L${INSTALL_PREFIX}/lib"
    export PKG_CONFIG_PATH="${INSTALL_PREFIX}/lib/pkgconfig"
    export PKG_CONFIG="pkg-config"

    # Remove PATH entries containing spaces. Git for Windows tools appear at
    # paths like "/c/Program Files/Git/usr/bin/mkdir", which configure stores
    # unquoted and then bash word-splits on the space, causing every compiler
    # feature test to fail with "/c/Program: No such file or directory".
    export PATH=$(python -c "
import sys
parts = sys.argv[1].split(':')
print(':'.join(p for p in parts if ' ' not in p and p))
" "$PATH")

    # Pre-set autoconf cache variables to bypass MSYS2 expr limitations.
    # MSYS2's /usr/bin/expr returns 0 for BRE \( \) capture groups, causing
    # EXEEXT and OBJEXT to be detected as "0" instead of ".exe" and "o",
    # which makes all subsequent compiler feature checks fail (they look for
    # "conftest.0" instead of "conftest.exe").
    export ac_cv_exeext='.exe'
    export ac_cv_objext='o'

    # MSYS2's /usr/bin/expr also corrupts --opt=VALUE parsing in autoconf
    # (returns 0 instead of VALUE). Use an array with space separators so
    # configure does direct assignment (no expr call) for all options.
    configure_args=(
        --prefix "${INSTALL_PREFIX}"
        --libdir "${INSTALL_PREFIX}/lib"
    )
    if [[ "${CC}" == x86_64-w64-mingw32-gcc ]]; then
        configure_args+=(--host x86_64-w64-mingw32)
    fi

    # Set SHELL and CONFIG_SHELL to the current bash executable (no spaces in path).
    # configure's line ~261 re-execs itself via: exec $SHELL "$0" "$@"
    # If $SHELL is "/c/Program Files/Git/usr/bin/bash.exe" (has spaces), bash
    # word-splits it and tries to exec "/c/Program" — which doesn't exist.
    # $BASH is set by bash itself to the running executable's full path and is
    # always a no-space m2-bash path, so it's safe to use for re-exec.
    export SHELL="${BASH}"
    export CONFIG_SHELL="${BASH}"

    if "${BASH}" ./configure "${configure_args[@]}"; then
        echo "configure: OK"
    else
        echo "=== configure FAILED — config.log tail ==="
        tail -80 config.log 2>/dev/null || echo "(no config.log found)"
        exit 1
    fi
else
    export CFLAGS="-O2 -g -fPIC ${CFLAGS:-} -L${PREFIX}/lib -Wl,-rpath,${PREFIX}/lib"
    ./configure --prefix="${PREFIX}" --libdir="${PREFIX}/lib"
fi

make -j${CPU_COUNT}
if [[ "${CONDA_BUILD_CROSS_COMPILATION}" != "1" && "${target_platform}" != win* ]]; then
    make check
fi
make install
