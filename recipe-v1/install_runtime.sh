#!/bin/bash
set -exo pipefail

# install_runtime.sh — installs only the libpq shared library and pg_config.
#
# Strategy: run `make install`, then strip down the installation to just the
# two files owned by the libpq package.  Everything else (server binaries,
# contrib modules, headers, etc.) will be installed by the postgresql output.
#
# On Windows (MinGW) files land under $PREFIX/Library/ (Windows ecosystem
# layout).  On Unix they land directly under $PREFIX.

if [[ "${target_platform}" == win* ]]; then
    INSTALL_PREFIX="${PREFIX}/Library"
else
    INSTALL_PREFIX="${PREFIX}"
fi

make install

# -----------------------------------------------------------------------
# Prune to libpq library + pg_config only.
# -----------------------------------------------------------------------
mkdir -p backup/bin

if [[ "${target_platform}" == win* ]]; then
    # MinGW names the shared library libpq.dll and places it in bin/.
    # The import library is libpq.dll.a in lib/.
    # pg_config.exe is also in bin/.
    cp "${INSTALL_PREFIX}/bin/libpq.dll"      backup/bin/
    cp "${INSTALL_PREFIX}/bin/pg_config.exe"  backup/bin/

    # Wipe all executables from bin/ then restore just our two files.
    rm -f "${INSTALL_PREFIX}/bin/"*.exe "${INSTALL_PREFIX}/bin/"*.dll
    mv backup/bin/libpq.dll     "${INSTALL_PREFIX}/bin/"
    mv backup/bin/pg_config.exe "${INSTALL_PREFIX}/bin/"
else
    # On Unix, keep pg_config in bin/ and leave the shared library in lib/.
    # Wipe the rest of bin/ (all server executables).
    cp "${INSTALL_PREFIX}/bin/pg_config" backup/bin/
    rm -rf "${INSTALL_PREFIX}/bin/"*
    mv backup/bin/pg_config "${INSTALL_PREFIX}/bin/"
fi
