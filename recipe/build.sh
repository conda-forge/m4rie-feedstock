#!/bin/bash
# Get an updated config.sub and config.guess
cp $BUILD_PREFIX/share/libtool/build-aux/config.* .

autoreconf -ivf

if [[ "$target_platform" == "win-"* ]]; then
  export CFLAGS="$CFLAGS -DM4RI_USE_DLL"
fi

./configure --prefix=$PREFIX --libdir=$PREFIX/lib --disable-static

[[ "$target_platform" == "win-"* ]] && patch_libtool

make -j${CPU_COUNT}
if [[ "${CONDA_BUILD_CROSS_COMPILATION}" != "1" || "${CROSSCOMPILING_EMULATOR:-}" != "" ]]; then
  make check -j${CPU_COUNT}
fi
make install
