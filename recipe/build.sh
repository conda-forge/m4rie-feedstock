#!/bin/bash

export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${PREFIX}/lib"
export CFLAGS="-O2 -g -fPIC $CFLAGS"

if [ "$(uname)" == "Linux" ]
then
   export LDFLAGS="$LDFLAGS -Wl,-rpath-link,${PREFIX}/lib"
fi

# Get rid of any `.la` from defaults.
find $PREFIX/lib -name '*.la' -delete


chmod +x configure

./configure --prefix=$PREFIX --libdir=$PREFIX/lib --disable-sse2

make
make check
make install
