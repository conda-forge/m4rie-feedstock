#!/bin/bash
set -euo pipefail

if [[ "${target_platform}" == win* ]]; then
    # Debug: show what conda-build set
    echo "=== PATH DIAGNOSTICS ==="
    echo "PREFIX=${PREFIX:-UNSET}"
    echo "LIBRARY_PREFIX=${LIBRARY_PREFIX:-UNSET}"
    echo "CYGWIN_PREFIX=${CYGWIN_PREFIX:-UNSET}"
    echo "CC=${CC:-UNSET}"
    echo "========================"

    # Use Python (always available) to convert Windows path to POSIX for autotools.
    # LIBRARY_PREFIX=C:\bld\...\Library  ->  /c/bld/.../Library
    INSTALL_PREFIX=$(python -c "
import os
p = os.environ['LIBRARY_PREFIX'].replace('\\\\', '/')
drive, rest = p.split(':', 1)
print('/' + drive.lower() + rest)
")
    echo "INSTALL_PREFIX=${INSTALL_PREFIX}"

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
