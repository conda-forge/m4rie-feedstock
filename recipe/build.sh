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

    # MSYS2's /usr/bin/expr does not support POSIX BRE \( \) capture groups,
    # so any option passed as --opt=VALUE has its value extracted as "0" by:
    #   ac_optarg=`expr "x$ac_option" : 'x[^=]*=\(.*\)'`
    # Using --opt VALUE (space, not =) makes configure do direct assignment
    # with no expr call, bypassing the broken expr for ALL options.
    # We use a bash array to safely handle the optional --host argument.
    configure_args=(
        --prefix "${INSTALL_PREFIX}"
        --libdir "${INSTALL_PREFIX}/lib"
    )
    if [[ "${CC}" == x86_64-w64-mingw32-gcc ]]; then
        configure_args+=(--host x86_64-w64-mingw32)
    fi

    if bash ./configure "${configure_args[@]}"; then
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
