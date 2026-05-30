#!/bin/bash
set -exo pipefail

# install_db.sh — installs the full postgresql server + contrib modules.
#
# On Windows (MinGW) the build was configured with
#   --prefix=$PREFIX/Library
# so `make install` already puts everything under the Windows ecosystem layout:
#   $PREFIX/Library/bin/    ← .exe and .dll files
#   $PREFIX/Library/lib/    ← import libraries (.dll.a)
#   $PREFIX/Library/include/
#   $PREFIX/Library/share/
#
# On Unix everything lands directly under $PREFIX.

make install
make install -C contrib
