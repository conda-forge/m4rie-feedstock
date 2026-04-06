#!/bin/bash
set -euo pipefail

if [[ "${target_platform}" == win* ]]; then
    # On Windows, conda expects headers/libs under $PREFIX/Library.
    # PREFIX is a Windows path (C:\...) which autotools rejects unless converted.
    POSIX_PREFIX="$(cygpath -u "${PREFIX}")"
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
