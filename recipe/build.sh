#!/bin/bash

export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${PREFIX}/lib"
export CFLAGS="-O2 -g -fPIC $CFLAGS -L${PREFIX}/lib"

chmod +x configure

./configure --prefix=$PREFIX --libdir=$PREFIX/lib

make
make check
make install
