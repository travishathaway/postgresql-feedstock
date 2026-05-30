#!/bin/bash
set -exo pipefail

# On Windows (MSYS2/MinGW), set up the correct prefix layout.
# conda-forge Windows uses $PREFIX/Library as the root for libraries/headers.
if [[ "${target_platform}" == win* ]]; then
    INSTALL_PREFIX="${PREFIX}/Library"
else
    INSTALL_PREFIX="${PREFIX}"
fi

# Get an updated config.sub and config.guess (Unix only — gnuconfig is not
# in the build environment on Windows).
if [[ "${target_platform}" != win* ]]; then
    cp $BUILD_PREFIX/share/gnuconfig/config.* ./config
fi

# Avoid absolute paths in compiler variables so that the build system
# does not embed host-specific paths into generated Makefiles.
export CC=$(basename "$CC")
export CXX=$(basename "$CXX")
# FC may not be set on all platforms; guard it.
if [[ -n "${FC:-}" ]]; then
    export FC=$(basename "$FC")
fi

# Use lld linker on macOS.
if [[ "${target_platform}" == osx* ]]; then
    export LD=ld.lld
    export LDFLAGS="${LDFLAGS} -fuse-ld=lld"
fi

# -----------------------------------------------------------------------
# Platform-specific feature flags
# -----------------------------------------------------------------------
EXTRA_FEATURES=""
EXTRA_CONFIG_ARGS=""

if [[ "${target_platform}" == linux* ]]; then
    EXTRA_FEATURES+=" --with-liburing"
fi

if [[ "${CONDA_BUILD_CROSS_COMPILATION}" == "1" && "${target_platform}" == linux* ]]; then
    EXTRA_CONFIG_ARGS+=" LDFLAGS_EX_BE=-Wl,--export-dynamic"
fi

# ARMv8+ CRC32/SVE vector support — expose HWCAP bits to configure probes.
if [[ "${target_platform}" == "linux-aarch64" ]]; then
    export CPPFLAGS="${CPPFLAGS:-} -DHWCAP_CRC32=0x80 -DHWCAP_SVE=0x400000"
fi

# -----------------------------------------------------------------------
# Windows (MinGW/MSYS2) configure
# -----------------------------------------------------------------------
if [[ "${target_platform}" == win* ]]; then
    # Tell autoconf we are cross-compiling to the mingw-w64 target even
    # though we are running inside an MSYS2 shell on the same machine.
    EXTRA_CONFIG_ARGS+=" --host=x86_64-w64-mingw32"
    EXTRA_CONFIG_ARGS+=" --build=x86_64-w64-mingw32"

    # openldap is not available on Windows.
    # tzdata / tzcode are not used on Windows (it reads the registry).
    # libuuid (e2fs) is not available on Windows — skip UUID support.
    WIN_ONLY_FLAGS="--without-ldap --without-uuid"

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
        ${WIN_ONLY_FLAGS} \
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
# Tests (native builds only, Linux-64 for now to match original recipe)
# -----------------------------------------------------------------------
if [[ "${CONDA_BUILD_CROSS_COMPILATION}" != "1" ]]; then
    if [[ "${target_platform}" == "linux-64" ]]; then
        make check
        make check -C contrib
    fi
fi
