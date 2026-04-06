#!/bin/bash
set -euo pipefail

if [[ "${target_platform}" == win* ]]; then
    # On Windows, conda expects headers/libs under $PREFIX/Library
    export CFLAGS="-O2 -g $CFLAGS -L${PREFIX}/Library/lib"
    ./configure --prefix="${PREFIX}/Library" --libdir="${PREFIX}/Library/lib"
else
    export CFLAGS="-O2 -g -fPIC $CFLAGS -L${PREFIX}/lib -Wl,-rpath,${PREFIX}/lib"
    ./configure --prefix="${PREFIX}" --libdir="${PREFIX}/lib"
fi

make -j${CPU_COUNT}
if [[ "${CONDA_BUILD_CROSS_COMPILATION}" != "1" ]]; then
    make check
fi
make install
