#!/bin/bash
set -exo pipefail

# On Windows (MSYS2/MinGW) the conda-forge Windows ecosystem layout puts
# libraries under $PREFIX/Library rather than directly under $PREFIX.
# We configure PostgreSQL's --prefix accordingly so that everything lands
# in the right place without any post-install shuffling.
if [[ "${target_platform}" == win* ]]; then
    INSTALL_PREFIX="${PREFIX}/Library"
else
    INSTALL_PREFIX="${PREFIX}"
fi

# -----------------------------------------------------------------------
# config.sub / config.guess — only available via gnuconfig on Unix
# -----------------------------------------------------------------------
if [[ "${target_platform}" != win* ]]; then
    cp "$BUILD_PREFIX/share/gnuconfig/config."* ./config
fi

# -----------------------------------------------------------------------
# Shorten compiler paths so they are not embedded verbatim into Makefiles.
# -----------------------------------------------------------------------
export CC=$(basename "$CC")
export CXX=$(basename "$CXX")
if [[ -n "${FC:-}" ]]; then
    export FC=$(basename "$FC")
fi

# -----------------------------------------------------------------------
# macOS: use lld
# -----------------------------------------------------------------------
if [[ "${target_platform}" == osx* ]]; then
    export LD=ld.lld
    export LDFLAGS="${LDFLAGS} -fuse-ld=lld"
fi

# -----------------------------------------------------------------------
# Platform-specific feature / configure flags
# -----------------------------------------------------------------------
EXTRA_FEATURES=""
EXTRA_CONFIG_ARGS=""

if [[ "${target_platform}" == linux* ]]; then
    EXTRA_FEATURES+=" --with-liburing"
fi

if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" == "1" && "${target_platform}" == linux* ]]; then
    EXTRA_CONFIG_ARGS+=" LDFLAGS_EX_BE=-Wl,--export-dynamic"
fi

# ARMv8+ CRC32/SVE vector support
if [[ "${target_platform}" == "linux-aarch64" ]]; then
    export CPPFLAGS="${CPPFLAGS:-} -DHWCAP_CRC32=0x80 -DHWCAP_SVE=0x400000"
fi

# -----------------------------------------------------------------------
# Windows (MinGW-w64 / MSYS2) configure
# -----------------------------------------------------------------------
if [[ "${target_platform}" == win* ]]; then
    # Explicitly target the MinGW-w64 64-bit ABI.
    EXTRA_CONFIG_ARGS+=" --host=x86_64-w64-mingw32"
    EXTRA_CONFIG_ARGS+=" --build=x86_64-w64-mingw32"

    # winflexbison installs win_bison.exe and win_flex.exe under
    # $BUILD_PREFIX/Library/bin.  Point PostgreSQL's configure at them
    # and tell win_bison where to find its skeleton data files.
    WIN_TOOLS_BIN="${BUILD_PREFIX}/Library/bin"
    export BISON="${WIN_TOOLS_BIN}/win_bison.exe"
    export FLEX="${WIN_TOOLS_BIN}/win_flex.exe"
    export BISON_PKGDATADIR="${WIN_TOOLS_BIN}/data"

    ./configure \
        --prefix="${INSTALL_PREFIX}" \
        --with-libraries="${INSTALL_PREFIX}/lib" \
        --with-includes="${INSTALL_PREFIX}/include" \
        --enable-thread-safety \
        --with-gssapi \
        --with-icu \
        --with-libxml \
        --with-libxslt \
        --with-lz4 \
        --with-ssl=openssl \
        --with-zstd \
        --without-ldap \
        --without-uuid \
        ${EXTRA_FEATURES} \
        ${EXTRA_CONFIG_ARGS}

# -----------------------------------------------------------------------
# Unix (Linux / macOS) configure
# -----------------------------------------------------------------------
else
    ./configure \
        --prefix="${INSTALL_PREFIX}" \
        --with-libraries="${INSTALL_PREFIX}/lib" \
        --with-includes="${INSTALL_PREFIX}/include" \
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
        --with-system-tzdata="${PREFIX}/share/zoneinfo" \
        PG_SYSROOT="undefined" \
        ${EXTRA_FEATURES} \
        ${EXTRA_CONFIG_ARGS}
fi

# -----------------------------------------------------------------------
# Build
# -----------------------------------------------------------------------
make -j "${CPU_COUNT}"
make -j "${CPU_COUNT}" -C contrib

# -----------------------------------------------------------------------
# Run tests on native Linux-64 builds only (matches original recipe).
# -----------------------------------------------------------------------
if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" != "1" ]]; then
    if [[ "${target_platform}" == "linux-64" ]]; then
        make check
        make check -C contrib
    fi
fi
