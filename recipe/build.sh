#!/bin/bash

if [[ "$target_platform" == "win-"* ]]; then
  export CFLAGS="$CFLAGS -DM4RI_USE_DLL -Wl,-rpath,${PREFIX}/lib -L${PREFIX}/lib"
else
  # Get an updated config.sub and config.guess
  cp $BUILD_PREFIX/share/libtool/build-aux/config.* .
fi

autoreconf -ivf


./configure --prefix=$PREFIX --libdir=$PREFIX/lib --disable-static

[[ "$target_platform" == "win-"* ]] && patch_libtool

make -j${CPU_COUNT}
if [[ "${CONDA_BUILD_CROSS_COMPILATION}" != "1" || "${CROSSCOMPILING_EMULATOR:-}" != "" ]]; then
  make check || (cat tests/test-suite.log; false)
fi
make install
