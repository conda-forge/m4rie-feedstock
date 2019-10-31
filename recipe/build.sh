#!/bin/bash

export CFLAGS="-O2 -g -fPIC $CFLAGS -L${PREFIX}/lib -Wl,-rpath,${PREFIX}/lib"

chmod +x configure

./configure --prefix=$PREFIX --libdir=$PREFIX/lib

make
make check
make install
