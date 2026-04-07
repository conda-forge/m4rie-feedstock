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
        CONFIGURE_HOST="--host=x86_64-w64-mingw32"
        echo "Using MinGW cross-compiler: $(which x86_64-w64-mingw32-gcc)"
    else
        echo "WARNING: x86_64-w64-mingw32-gcc not found, falling back to gcc"
        export CC=gcc
        CONFIGURE_HOST=""
    fi

    # Override CFLAGS completely — conda-build sets MSVC flags when vs2022_win-64
    # is in build requirements; those flags are incompatible with MinGW.
    export CFLAGS="-O2 -g"
    export CPPFLAGS="-I${INSTALL_PREFIX}/include"
    export LDFLAGS="-L${INSTALL_PREFIX}/lib"
    export PKG_CONFIG_PATH="${INSTALL_PREFIX}/lib/pkgconfig"
    export PKG_CONFIG="pkg-config"

    # Diagnostic: verify which expr is found and whether it supports \( \) BRE
    # capture groups. If it prints "0" or fails, the PATH has a broken expr.
    echo "expr binary: $(which expr 2>/dev/null || echo NOT_FOUND)"
    echo "expr capture test: $(expr "x--prefix=${INSTALL_PREFIX}" : 'x[^=]*=\(.*\)' 2>&1 || true)"

    # Fix: autoconf's configure extracts --prefix=VALUE via:
    #   ac_optarg=`expr "x$ac_option" : 'x[^=]*=\(.*\)'`
    # If 'expr' in PATH doesn't support \( \) BRE capture groups (e.g. a
    # Windows-native binary from the MinGW bin dir), this returns "0" and
    # prefix becomes "0", triggering "expected an absolute directory" error.
    #
    # Using --prefix VALUE (space, no =) bypasses this expr call entirely:
    # configure does  eval $ac_prev=\$ac_option  (direct assignment, no expr).
    # shellcheck disable=SC2086
    if bash ./configure ${CONFIGURE_HOST} \
            --prefix "${INSTALL_PREFIX}" \
            --libdir "${INSTALL_PREFIX}/lib"; then
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
