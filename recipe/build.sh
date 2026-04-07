#!/bin/bash
set -euo pipefail

if [[ "${target_platform}" == win* ]]; then
    # MSYS2 bash may hang if /tmp doesn't exist
    mkdir -p /tmp

    # Use POSIX-style path (starts with /) — autoconf accepts it as absolute.
    INSTALL_PREFIX=$(python -c "
import os
p = os.environ['LIBRARY_PREFIX'].replace('\\\\', '/')
drive, rest = p.split(':', 1)
print('/' + drive.lower() + rest)
")
    echo "INSTALL_PREFIX=${INSTALL_PREFIX}"

    # Locate the MinGW-w64 cross-compiler
    if command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1; then
        export CC=x86_64-w64-mingw32-gcc
        # Use full POSIX paths so libtool can invoke these tools without
        # relying on PATH lookup inside its shell sub-invocations.
        export AR=$(command -v x86_64-w64-mingw32-ar)
        export RANLIB=$(command -v x86_64-w64-mingw32-ranlib)
        export STRIP=$(command -v x86_64-w64-mingw32-strip)
        export NM=$(command -v x86_64-w64-mingw32-nm)
        export DLLTOOL=$(command -v x86_64-w64-mingw32-dlltool)
        export OBJDUMP=$(command -v x86_64-w64-mingw32-objdump)
        echo "Using MinGW cross-compiler: $(which x86_64-w64-mingw32-gcc)"
        echo "AR=${AR}  RANLIB=${RANLIB}"
    else
        echo "WARNING: x86_64-w64-mingw32-gcc not found, falling back to gcc"
        export CC=gcc
    fi

    # Override CFLAGS completely — conda-build sets MSVC flags when vs2022_win-64
    # is in build requirements; those flags are incompatible with MinGW.
    export CFLAGS="-O2 -g"
    export CPPFLAGS="-I${INSTALL_PREFIX}/include"
    export LDFLAGS="-L${INSTALL_PREFIX}/lib"
    export PKG_CONFIG_PATH="${INSTALL_PREFIX}/lib/pkgconfig"
    export PKG_CONFIG="pkg-config"

    # Remove PATH entries containing spaces. Git for Windows tools appear at
    # paths like "/c/Program Files/Git/usr/bin/mkdir", which configure stores
    # unquoted and then bash word-splits on the space, causing every compiler
    # feature test to fail with "/c/Program: No such file or directory".
    # Use pure bash — passing $PATH as an argument to native Windows Python
    # triggers MSYS2's auto-conversion from POSIX (:) to Windows (;) format,
    # which breaks the split and wipes everything from PATH.
    IFS=: read -ra _path_arr <<< "$PATH"
    _clean_path=""
    for _p in "${_path_arr[@]}"; do
        case "$_p" in
            *\ *|'') ;;
            *) _clean_path="${_clean_path:+$_clean_path:}$_p" ;;
        esac
    done
    export PATH="$_clean_path"
    unset _path_arr _clean_path _p

    # Diagnostics: confirm key tools are reachable after PATH filter
    echo "=== tool check after PATH filter ==="
    for _t in sed expr grep make; do
        if command -v "$_t" >/dev/null 2>&1; then
            echo "  $_t: $(command -v "$_t")"
        else
            echo "  $_t: NOT FOUND"
        fi
    done
    unset _t
    echo "=== first 10 PATH entries ==="
    printf '%s\n' "$PATH" | tr ':' '\n' | head -10
    echo "==="

    # Pre-set autoconf cache variables to bypass MSYS2 expr limitations.
    # MSYS2's /usr/bin/expr returns 0 for BRE \( \) capture groups, causing
    # EXEEXT and OBJEXT to be detected as "0" instead of ".exe" and "o",
    # which makes all subsequent compiler feature checks fail (they look for
    # "conftest.0" instead of "conftest.exe").
    export ac_cv_exeext='.exe'
    export ac_cv_objext='o'

    # MSYS2's /usr/bin/expr also corrupts --opt=VALUE parsing in autoconf
    # (returns 0 instead of VALUE). Use an array with space separators so
    # configure does direct assignment (no expr call) for all options.
    configure_args=(
        --prefix "${INSTALL_PREFIX}"
        --libdir "${INSTALL_PREFIX}/lib"
    )
    if [[ "${CC}" == x86_64-w64-mingw32-gcc ]]; then
        configure_args+=(--host x86_64-w64-mingw32)
    fi

    # Set SHELL and CONFIG_SHELL to the current bash executable (no spaces in path).
    # configure's line ~261 re-execs itself via: exec $SHELL "$0" "$@"
    # If $SHELL is "/c/Program Files/Git/usr/bin/bash.exe" (has spaces), bash
    # word-splits it and tries to exec "/c/Program" — which doesn't exist.
    # $BASH is set by bash itself to the running executable's full path and is
    # always a no-space m2-bash path, so it's safe to use for re-exec.
    export SHELL="${BASH}"
    export CONFIG_SHELL="${BASH}"

    # Diagnose what m4ri provides — needed to understand whether libtool
    # will be able to build a shared libm4rie.dll or only a static library.
    echo "=== m4ri library files ==="
    ls -la "${INSTALL_PREFIX}/lib/" | grep -i m4ri || echo "  (none in lib/)"
    ls -la "${INSTALL_PREFIX}/bin/" | grep -i m4ri || echo "  (none in bin/)"
    echo "=== m4ri pkg-config libs ==="
    pkg-config --libs m4ri 2>&1 || true
    echo "==="

    if "${BASH}" ./configure "${configure_args[@]}"; then
        echo "configure: OK"

        # Show what configure stored in libtool for the cross-tools.
        echo "=== libtool AR/NM/RANLIB assignments ==="
        grep -E "^(AR|NM|RANLIB|DLLTOOL|STRIP|OBJDUMP)=" ./libtool | head -10

        # libtool searches for libm4ri.dll.a to detect m4ri as a shared library.
        # conda-forge's m4ri package (built with MinGW+libtool) ships m4ri.lib
        # (the libtool-generated MSVC-compat import library) but omits libm4ri.dll.a.
        # Provide libm4ri.dll.a so libtool's func_cygming_*_implib_p checks succeed
        # without falling back to func_cygming_dll_for_implib_fallback (which
        # calls AR and fails when ar can't find the file).
        if [[ -f "${INSTALL_PREFIX}/lib/m4ri.lib" && ! -f "${INSTALL_PREFIX}/lib/libm4ri.dll.a" ]]; then
            echo "=== Creating libm4ri.dll.a (copy of m4ri.lib) for libtool detection ==="
            cp "${INSTALL_PREFIX}/lib/m4ri.lib" "${INSTALL_PREFIX}/lib/libm4ri.dll.a"
            echo "  created ${INSTALL_PREFIX}/lib/libm4ri.dll.a"
        fi
    else
        echo "=== configure FAILED — config.log tail ==="
        tail -80 config.log 2>/dev/null || echo "(no config.log found)"
        exit 1
    fi
else
    export CFLAGS="-O2 -g -fPIC ${CFLAGS:-} -L${PREFIX}/lib -Wl,-rpath,${PREFIX}/lib"
    ./configure --prefix="${PREFIX}" --libdir="${PREFIX}/lib"
fi

# Serial make on Windows.  Explicit -j1 overrides any MAKEFLAGS=-jN that
# the environment or conda-build might have set, ensuring no parallel jobs
# race the libm4rie.la link rule against still-compiling .lo files.
if [[ "${target_platform}" == win* ]]; then
    unset MAKEFLAGS
    make -j1
else
    make -j${CPU_COUNT}
fi
if [[ "${CONDA_BUILD_CROSS_COMPILATION}" != "1" && "${target_platform}" != win* ]]; then
    make check
fi
make install
