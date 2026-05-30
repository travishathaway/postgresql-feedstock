#!/bin/bash
set -exo pipefail

# On Windows (MinGW) the build was configured with
# --prefix=$PREFIX/Library, so `make install` already puts everything
# under the correct Windows ecosystem layout:
#   $PREFIX/Library/bin/   ← .exe and .dll files
#   $PREFIX/Library/lib/   ← import libraries (.dll.a)
#   $PREFIX/Library/include/
#   $PREFIX/Library/share/
#
# On Unix everything lands under $PREFIX directly.

make install
make install -C contrib
