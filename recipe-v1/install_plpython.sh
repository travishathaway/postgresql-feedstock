#!/bin/bash
set -exo pipefail

# plpython is a Unix-only output (skipped on Windows in the recipe).
# We re-run configure with --with-python added so that the plpython
# extension modules are built against the correct Python interpreter.

cp $BUILD_PREFIX/share/gnuconfig/config.* ./config

export CC=$(basename "$CC")
export CXX=$(basename "$CXX")
if [[ -n "${FC:-}" ]]; then
    export FC=$(basename "$FC")
fi

if [[ "${target_platform}" == osx* ]]; then
    export LD=ld.lld
    export LDFLAGS="${LDFLAGS} -fuse-ld=lld"
fi

export PYTHON=$PREFIX/bin/python

./configure \
    --prefix=$PREFIX \
    --with-libraries=$PREFIX/lib \
    --with-includes=$PREFIX/include \
    --enable-thread-safety \
    --with-gssapi \
    --with-icu \
    --with-ldap \
    --with-libxml \
    --with-libxslt \
    --with-lz4 \
    --with-ssl=openssl \
    --with-uuid=e2fs \
    --with-zstd \
    --with-system-tzdata=$PREFIX/share/zoneinfo \
    --with-python \
    PG_SYSROOT="undefined"

for dir in src/pl/plpython contrib/hstore_plpython; do
    pushd $dir
    make clean
    make
    make install
    popd
done
