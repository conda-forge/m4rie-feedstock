#!/bin/bash

export CFLAGS="-O2 -g -fPIC $CFLAGS"

# Get rid of any `.la` from defaults.
find $PREFIX/lib -name '*.la' -delete

chmod +x configure

./configure --prefix=$PREFIX --libdir=$PREFIX/lib --disable-sse2

make
make check
make install
