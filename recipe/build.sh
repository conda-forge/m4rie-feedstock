#!/bin/bash
set -euo pipefail

if [[ "${target_platform}" == win* ]]; then
    # MSYS2 bash may hang if /tmp doesn't exist
    mkdir -p /tmp

    # PREFIX is unexpanded (%PREFIX%) in bash — use Python to get the real path
    # from the Windows environment (correctly set by conda activate).
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
        CONFIGURE_HOST="--host=x86_64-w64-mingw32"
        echo "Using MinGW cross-compiler: $(which x86_64-w64-mingw32-gcc)"
    else
        echo "WARNING: x86_64-w64-mingw32-gcc not found, falling back to gcc"
        export CC=gcc
        CONFIGURE_HOST=""
    fi

    # Diagnostics
    echo "=== pwd ==="
    pwd
    echo "=== configure exists? ==="
    ls -la configure 2>&1 || echo "ERROR: configure script not found"
    echo "=== PATH (first 10) ==="
    echo "$PATH" | tr ':' '\n' | head -10

    # Separate CFLAGS/CPPFLAGS/LDFLAGS for correct cross-compilation behaviour.
    # Use bash ./configure (not ./configure) to bypass MSYS2 execute-bit issues.
    export CFLAGS="-O2 -g ${CFLAGS:-}"
    export CPPFLAGS="-I${INSTALL_PREFIX}/include ${CPPFLAGS:-}"
    export LDFLAGS="-L${INSTALL_PREFIX}/lib ${LDFLAGS:-}"
    export PKG_CONFIG_PATH="${INSTALL_PREFIX}/lib/pkgconfig"
    export PKG_CONFIG="pkg-config"

    # shellcheck disable=SC2086
    bash ./configure ${CONFIGURE_HOST} \
        --prefix="${INSTALL_PREFIX}" \
        --libdir="${INSTALL_PREFIX}/lib"
else
    export CFLAGS="-O2 -g -fPIC ${CFLAGS:-} -L${PREFIX}/lib -Wl,-rpath,${PREFIX}/lib"
    ./configure --prefix="${PREFIX}" --libdir="${PREFIX}/lib"
fi

make -j${CPU_COUNT}
if [[ "${CONDA_BUILD_CROSS_COMPILATION}" != "1" && "${target_platform}" != win* ]]; then
    make check
fi
make install
