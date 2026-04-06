#!/bin/bash
set -euo pipefail

if [[ "${target_platform}" == win* ]]; then
    # On Windows, conda expects headers/libs under $PREFIX/Library.
    # conda-build sets CYGWIN_PREFIX=/cygdrive/c/bld/..._h_env (Cygwin format).
    # Strip /cygdrive to get MSYS2 format: /c/bld/..._h_env
    POSIX_PREFIX="${CYGWIN_PREFIX/\/cygdrive/}"
    INSTALL_PREFIX="${POSIX_PREFIX}/Library"
    export CFLAGS="-O2 -g ${CFLAGS:-} -L${INSTALL_PREFIX}/lib"
    ./configure --prefix="${INSTALL_PREFIX}" --libdir="${INSTALL_PREFIX}/lib"
else
    export CFLAGS="-O2 -g -fPIC ${CFLAGS:-} -L${PREFIX}/lib -Wl,-rpath,${PREFIX}/lib"
    ./configure --prefix="${PREFIX}" --libdir="${PREFIX}/lib"
fi

make -j${CPU_COUNT}
if [[ "${CONDA_BUILD_CROSS_COMPILATION}" != "1" && "${target_platform}" != win* ]]; then
    make check
fi
make install
