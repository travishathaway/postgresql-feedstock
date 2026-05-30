#!/bin/bash
set -exo pipefail

# Install everything from the full build, then strip it down to only the
# files that belong in the libpq package:
#   - libpq shared library
#   - pg_config helper binary
#
# On Windows (MinGW) the layout under $PREFIX/Library mirrors the Unix
# layout under $PREFIX, so we use a single code-path with an
# INSTALL_PREFIX variable.

if [[ "${target_platform}" == win* ]]; then
    INSTALL_PREFIX="${PREFIX}/Library"
else
    INSTALL_PREFIX="${PREFIX}"
fi

make install

# -----------------------------------------------------------------------
# Prune the install to just the libpq runtime + pg_config.
# Save the files we want to keep, wipe the rest, then restore.
# -----------------------------------------------------------------------
mkdir -p backup/bin

if [[ "${target_platform}" == win* ]]; then
    # MinGW installs the shared library as:
    #   $INSTALL_PREFIX/bin/libpq.dll
    #   $INSTALL_PREFIX/lib/libpq.dll.a   (import library)
    # and the config helper as:
    #   $INSTALL_PREFIX/bin/pg_config.exe

    cp "${INSTALL_PREFIX}/bin/libpq.dll"       backup/bin/
    cp "${INSTALL_PREFIX}/bin/pg_config.exe"   backup/bin/
    cp -r "${INSTALL_PREFIX}/lib"              backup/lib || true
    cp -r "${INSTALL_PREFIX}/include"          backup/include || true

    # Remove everything under the install prefix, then restore only what
    # the libpq package should own.
    rm -rf "${INSTALL_PREFIX:?}/bin"
    rm -rf "${INSTALL_PREFIX:?}/share"
    # Keep lib and include (they were backed up above and will be restored)

    mkdir -p "${INSTALL_PREFIX}/bin"
    mv backup/bin/libpq.dll     "${INSTALL_PREFIX}/bin/"
    mv backup/bin/pg_config.exe "${INSTALL_PREFIX}/bin/"

    # Restore import library and headers (needed for downstream builds).
    # The full lib/ and include/ trees are left in place by the install;
    # we only clean out executables, not libs/headers.

else
    # Unix: save pg_config, wipe bin/, restore it.
    cp "${INSTALL_PREFIX}/bin/pg_config" backup/bin/
    rm -rf "${INSTALL_PREFIX:?}/bin/"*
    mv backup/bin/pg_config "${INSTALL_PREFIX}/bin/"
fi
