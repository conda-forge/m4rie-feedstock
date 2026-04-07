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

    # Override CFLAGS completely — conda-build sets MSVC flags when vs2022_win-64
    # is in build requirements; those flags are incompatible with MinGW.
    export CFLAGS="-O2 -g"
    export CPPFLAGS="-I${INSTALL_PREFIX}/include"
    export LDFLAGS="-L${INSTALL_PREFIX}/lib"
    export PKG_CONFIG_PATH="${INSTALL_PREFIX}/lib/pkgconfig"
    export PKG_CONFIG="pkg-config"

    # Quick sanity check: can the cross-compiler build a trivial program?
    echo 'int main(void){return 0;}' > /tmp/_test_cc.c
    if ${CC} ${CFLAGS} -o /tmp/_test_cc.exe /tmp/_test_cc.c 2>&1; then
        echo "Compiler sanity test: OK"
    else
        echo "Compiler sanity test: FAILED"
    fi
    rm -f /tmp/_test_cc.c /tmp/_test_cc.exe

    # Use 'bash ./configure' to bypass #!/bin/sh shebang resolution issues
    # in m2-bash's minimal MSYS2 environment.
    # shellcheck disable=SC2086
    if ! bash ./configure ${CONFIGURE_HOST} \
            --prefix="${INSTALL_PREFIX}" \
            --libdir="${INSTALL_PREFIX}/lib"; then
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
