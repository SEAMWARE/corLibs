#!/usr/bin/env bash
#
# bootstrap.sh - clone and build the whole dependency stack the broker needs.
#
# This script lives IN the corLibs umbrella because the umbrella is what knows
# the build order. The recipe used to sit loose in a parent directory, outside
# version control, which meant it could not be run by CI and drifted out of date
# without anything noticing. It is now versioned next to the makefile it drives.
#
# What it does:
#   1. clones (or fast-forwards) every dependency as a SIBLING of this repo
#   2. builds and installs the whole stack in dependency order, via `make di`
#      here in the umbrella, which collects every lib*.{a,so} plus the corTest
#      runner into corLibs/{lib,bin}
#
# Siblings, not subdirectories: the broker's CMakeLists.txt and every lib's
# include paths resolve their dependencies as ../<name>, so the layout is part
# of the build contract.
#
# Usage:
#   ./bootstrap.sh                 # clone/update + build
#   PROTO=ssh ./bootstrap.sh       # SSH clone URLs instead of https
#   NOBUILD=1 ./bootstrap.sh       # clone only, skip the build
#   BASE=/somewhere ./bootstrap.sh # place the siblings elsewhere
#   JOBS=8 ./bootstrap.sh          # parallel build jobs
#
# After it completes, build the broker:
#   cd <BASE>/coraine && make di
#
# Copyright 2026 Seamware
#
set -euo pipefail

# The siblings belong next to THIS repo, so derive the base from the script's
# own location rather than assuming a fixed path. A checkout anywhere works.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="${BASE:-$(dirname "$HERE")}"
PROTO="${PROTO:-https}"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}"

CI_ORG="SEAMWARE"        # the cor* repos
KLIB_OWNER="kzangeli"    # the k-libs, on gitlab

#
# The k-lib pins come from ./klib-pins, which is the single source of truth -
# the broker's Dockerfile reads the same file. Do not restate them here.
#
PINS="$HERE/klib-pins"
[ -r "$PINS" ] || { echo "bootstrap.sh: cannot read $PINS"; exit 1; }

#
# repo : host : ref
#
# The cor* repos track master: they move together, and a pin between them would
# only ever be stale. corLibs itself is deliberately absent - you are standing
# in it.
#
REPOS=()
while read -r repo ref; do
  case "$repo" in ''|\#*) continue ;; esac
  REPOS+=("$repo:gitlab:$ref")
done < <(sed 's/#.*//' "$PINS")

REPOS+=(
  "corPlugin:github:master"
  "corRest:github:master"
  "corJsonld:github:master"
  "corNgsild:github:master"
  "corTest:github:master"
)

urlFor()
{
  local repo="$1" host="$2"

  if [ "$host" = gitlab ]; then
    [ "$PROTO" = ssh ] && echo "git@gitlab.com:$KLIB_OWNER/${repo}.git" \
                       || echo "https://gitlab.com/$KLIB_OWNER/${repo}.git"
  else
    [ "$PROTO" = ssh ] && echo "git@github.com:$CI_ORG/${repo}.git" \
                       || echo "https://github.com/$CI_ORG/${repo}.git"
  fi
}

echo ">>> umbrella : $HERE"
echo ">>> base dir : $BASE"
echo ">>> protocol : $PROTO"
echo ">>> jobs     : $JOBS"

mkdir -p "$BASE"

# ---------------------------------------------------------------------------
#
# 1. Clone or update every dependency, as a sibling.
#
for entry in "${REPOS[@]}"; do
  IFS=':' read -r repo host ref <<< "$entry"
  echo
  echo ">>> $repo ($host, $ref)"

  if [ -d "$BASE/$repo/.git" ]; then
    git -C "$BASE/$repo" fetch --all --quiet
    git -C "$BASE/$repo" checkout --quiet "$ref"
    # A pinned release branch has nothing to pull; master might. Never merge.
    git -C "$BASE/$repo" pull --ff-only --quiet || true
  else
    git clone --quiet --branch "$ref" "$(urlFor "$repo" "$host")" "$BASE/$repo"
  fi
done

# ---------------------------------------------------------------------------
#
# 2. Build + install the whole stack, in dependency order, through the umbrella.
#
if [ "${NOBUILD:-0}" = 1 ]; then
  echo
  echo ">>> NOBUILD=1 - repos are in place, build skipped."
  echo ">>> To build:  make -C $HERE di"
  exit 0
fi

echo
echo ">>> building the stack:  make -C $HERE -j$JOBS di"
make -C "$HERE" -j"$JOBS" di

echo
echo ">>> done - libs and the corTest runner are collected into $HERE/{lib,bin}."
echo ">>> next:  cd $BASE/coraine && make di"
