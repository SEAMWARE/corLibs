#!/usr/bin/env bash
#
# mongocBuild.sh - the MongoDB C driver (libmongoc2, libbson2), built from its release tarball: downloaded, checked,
# patched, installed
#
# Usage:  mongocBuild.sh [--prefix DIR] [--docdir DIR] [--sudo] [--keep] [-- <cmake options>]
#
#   MONGOC_VERSION  the release (default below); it must have a checksum here
#   --prefix DIR    where it is installed (default /usr/local)
#   --docdir DIR    where its licence (COPYING, THIRD_PARTY_NOTICES) and the patches applied to it are copied -
#                   whatever ships the library ships these with it (Apache-2.0 4(a), 4(b))
#   --sudo          `sudo cmake --install` (a runner, a workstation); without it: `cmake --install` (a container)
#   --keep          leave the build directory
#   -- ...          options for cmake, after the ones every build has (Release, no tests, no examples):
#                   the .deb's bundled build sets its install prefix, RUNPATH and TLS / SASL / compression
#
# The ONE place the stack builds the driver from: corLibs/docker/Dockerfile.ci (the CI image), coraine/docker/
# Dockerfile (the published image - docker/vendor-libs.sh stages this directory), coraine/.github/scripts/
# ci-env.sh (a bare runner, corLibs checked out beside coraine), coraine/packaging/deb/build.sh (the packages
# that bundle it) and a workstation all run this. A version is accepted only with its SHA-256 below - each one
# taken from a tarball whose signature (the release's .asc, MongoDB's C driver key, https://pgp.mongodb.com/
# c-driver.asc, fingerprint 6DB5 5D82 23FF 44E4 9DCB 9813 44E7 6C05 65AB C463) was checked when it was added - so
# a mirror cannot hand over a different driver. To add a version: download the tarball and its .asc from the
# GitHub release, `gpg --verify <tarball>.asc <tarball>` with that key, then its sha256sum here.
#
# Every patch in patches/<version>/ is applied, in name order. A patched driver behaves as the release does (each
# patch says why it exists and what it keeps); coraine works unchanged on an unpatched one. The last patch marks
# every file the others change as modified, a line at its top.
#
# Copyright 2026 Seamware
# SPDX-License-Identifier: Apache-2.0
#
set -euo pipefail

MONGOC_VERSION=${MONGOC_VERSION:-2.5.7}

declare -A SHA256=(
  [2.5.7]=fdd7c23b3d95f1ea08400e5a72e48419ce03d478aa12b28b4b66066867ee35ee
)

PREFIX=/usr/local
DOCDIR=""
SUDO=""
KEEP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --prefix) PREFIX=$2; shift 2 ;;
    --docdir) DOCDIR=$2; shift 2 ;;
    --sudo)   SUDO=sudo; shift ;;
    --keep)   KEEP=1; shift ;;
    --)       shift; break ;;
    *)        echo "mongocBuild.sh: unknown option '$1'" >&2; exit 1 ;;
  esac
done

want=${SHA256[$MONGOC_VERSION]:-}
[ -n "$want" ] || { echo "mongocBuild.sh: no checksum for mongo-c-driver $MONGOC_VERSION - add one (see the header)" >&2; exit 1; }

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/mongocBuild.XXXXXX")
[ $KEEP = 1 ] || trap 'rm -rf "$WORK"' EXIT

tarball="mongo-c-driver-$MONGOC_VERSION.tar.gz"
curl -fsSL "https://github.com/mongodb/mongo-c-driver/releases/download/$MONGOC_VERSION/$tarball" -o "$WORK/$tarball"

have=$(sha256sum "$WORK/$tarball" | cut -d' ' -f1)
if [ "$have" != "$want" ]; then
  echo "mongocBuild.sh: $tarball has SHA-256 $have, not $want - refused" >&2
  exit 1
fi

tar -xzf "$WORK/$tarball" -C "$WORK"
src="$WORK/mongo-c-driver-$MONGOC_VERSION"

for p in "$HERE/patches/$MONGOC_VERSION"/*.patch; do
  [ -e "$p" ] || continue
  echo "mongocBuild.sh: applying $(basename "$p")" >&2
  patch -d "$src" -p1 --forward --batch --fuzz=0 < "$p"
done

cmake -S "$src" -B "$src/build" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX" \
      -DENABLE_TESTS=OFF -DENABLE_EXAMPLES=OFF -DBUILD_TESTING=OFF "$@"
cmake --build "$src/build" -j"$(nproc)"
$SUDO cmake --install "$src/build"
if [ -n "$SUDO" ] || [ "$(id -u)" = 0 ]; then         # the linker cache is root's; a prefix of one's own needs none
  command -v ldconfig > /dev/null && $SUDO ldconfig
fi

if [ -n "$DOCDIR" ]; then
  $SUDO install -d "$DOCDIR"
  for f in COPYING THIRD_PARTY_NOTICES; do
    [ ! -f "$src/$f" ] || $SUDO install -m 0644 "$src/$f" "$DOCDIR/"
  done
  for p in "$HERE/patches/$MONGOC_VERSION"/*.patch; do
    [ -e "$p" ] || continue
    $SUDO install -d "$DOCDIR/patches"
    $SUDO install -m 0644 "$p" "$DOCDIR/patches/"
  done
fi

echo "mongocBuild.sh: mongo-c-driver $MONGOC_VERSION installed in $PREFIX" >&2
