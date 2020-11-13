#!/bin/bash
# Get an updated config.sub and config.guess
cp $BUILD_PREFIX/share/libtool/build-aux/config.* .

export CFLAGS="-O2 -g -fPIC $CFLAGS -L${PREFIX}/lib -Wl,-rpath,${PREFIX}/lib"

chmod +x configure

./configure --prefix=$PREFIX --libdir=$PREFIX/lib

make
if [[ "${CONDA_BUILD_CROSS_COMPILATION}" != "1" ]]; then
make check
fi
make install
