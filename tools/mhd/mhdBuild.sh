#!/usr/bin/env bash
#
# mhdBuild.sh - GNU libmicrohttpd, built from its release tarball: downloaded, checked, patched, installed
#
# Usage:  mhdBuild.sh [--prefix DIR] [--sudo] [--keep] [-- <configure options>]
#
#   MHD_VERSION   the release (default below); it must have a checksum here
#   --prefix DIR  where it is installed (default /usr/local)
#   --sudo        `sudo make install` (a runner, a workstation); without it: `make install` (a container)
#   --keep        leave the build directory
#   -- ...        options for ./configure, after the ones every build has (--disable-doc --disable-examples):
#                 --disable-https for an image without TLS notification endpoints, for instance
#
# The ONE place the stack builds libmicrohttpd from: corLibs/docker/Dockerfile.ci (the CI image),
# coraine/docker/Dockerfile (the published image - docker/vendor-libs.sh stages this directory), coraine/
# .github/scripts/ci-env.sh (a bare runner, corLibs checked out beside coraine) and a
# workstation all run this. A version is accepted only with its SHA-256 below - each one taken from a tarball
# whose GPG signature (ftp.gnu.org .sig, the GNU keyring) was checked when it was added - so a mirror cannot
# hand over a different HTTP server. To add a version: download the tarball and its .sig, `gpgv --keyring
# gnu-keyring.gpg <tarball>.sig <tarball>`, then its sha256sum here.
#
# Every patch in patches/<version>/ is applied, in name order. A patched library behaves as the release
# does (each patch says why it exists and what it keeps); coraine works unchanged on an unpatched one.
#
# Copyright 2026 Seamware
# SPDX-License-Identifier: Apache-2.0
#
set -euo pipefail

MHD_VERSION=${MHD_VERSION:-1.0.10}

declare -A SHA256=(
  [1.0.2]=df324fcd0834175dab07483133902d9774a605bfa298025f69883288fd20a8c7
  [1.0.10]=04bfe8ef75db7d629a33de767599765cecadc56274a39822d5d081030d577685
)

PREFIX=/usr/local
SUDO=""
KEEP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --prefix) PREFIX=$2; shift 2 ;;
    --sudo)   SUDO=sudo; shift ;;
    --keep)   KEEP=1; shift ;;
    --)       shift; break ;;
    *)        echo "mhdBuild.sh: unknown option '$1'" >&2; exit 1 ;;
  esac
done

want=${SHA256[$MHD_VERSION]:-}
[ -n "$want" ] || { echo "mhdBuild.sh: no checksum for libmicrohttpd $MHD_VERSION - add one (see the header)" >&2; exit 1; }

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/mhdBuild.XXXXXX")
[ $KEEP = 1 ] || trap 'rm -rf "$WORK"' EXIT

tarball="libmicrohttpd-$MHD_VERSION.tar.gz"
curl -fsSL "https://ftp.gnu.org/gnu/libmicrohttpd/$tarball" -o "$WORK/$tarball"

have=$(sha256sum "$WORK/$tarball" | cut -d' ' -f1)
if [ "$have" != "$want" ]; then
  echo "mhdBuild.sh: $tarball has SHA-256 $have, not $want - refused" >&2
  exit 1
fi

tar -xzf "$WORK/$tarball" -C "$WORK"
src="$WORK/libmicrohttpd-$MHD_VERSION"

for p in "$HERE/patches/$MHD_VERSION"/*.patch; do
  [ -e "$p" ] || continue
  echo "mhdBuild.sh: applying $(basename "$p")" >&2
  patch -d "$src" -p1 --forward --batch < "$p"
done

(
  cd "$src"
  ./configure --prefix="$PREFIX" --disable-doc --disable-examples "$@"
  make -j"$(nproc)"
  $SUDO make install
)
if [ -n "$SUDO" ] || [ "$(id -u)" = 0 ]; then         # the linker cache is root's; a prefix of one's own needs none
  command -v ldconfig > /dev/null && $SUDO ldconfig
fi

echo "mhdBuild.sh: libmicrohttpd $MHD_VERSION installed in $PREFIX" >&2
