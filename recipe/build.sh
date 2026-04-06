#!/bin/bash
set -euo pipefail

if [[ "${target_platform}" == win* ]]; then
    # On Windows, conda expects headers/libs under $PREFIX/Library.
    # PREFIX is unexpanded (%PREFIX%) in bash, so use Python to read the real
    # LIBRARY_PREFIX from the Windows environment (set correctly by conda activate).
    INSTALL_PREFIX=$(python -c "
import os
p = os.environ['LIBRARY_PREFIX'].replace('\\\\', '/')
drive, rest = p.split(':', 1)
print('/' + drive.lower() + rest)
")

    # Use the MinGW-w64 cross-compiler (m2w64-toolchain).
    # m4rie uses GCC intrinsics (__builtin_popcount etc.) incompatible with MSVC.
    export CC=x86_64-w64-mingw32-gcc
    export AR=x86_64-w64-mingw32-ar
    export RANLIB=x86_64-w64-mingw32-ranlib
    export STRIP=x86_64-w64-mingw32-strip
    export CFLAGS="-O2 -g ${CFLAGS:-} -L${INSTALL_PREFIX}/lib"

    ./configure \
        --host=x86_64-w64-mingw32 \
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
