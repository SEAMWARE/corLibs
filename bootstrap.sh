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
# SPDX-License-Identifier: Apache-2.0
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
# The cor* repos track main: they move together, and a pin between them would
# only ever be stale. corLibs itself is deliberately absent - you are standing
# in it.
#
REPOS=()
while read -r repo ref; do
  case "$repo" in ''|\#*) continue ;; esac
  REPOS+=("$repo:gitlab:$ref")
done < <(sed 's/#.*//' "$PINS")

REPOS+=(
  "corPlugin:github:main"
  "corRest:github:main"
  "corJsonld:github:main"
  "corNgsild:github:main"
  "corTest:github:main"
)

#
# gitRetry <label> <command...> - a hiccup at the far end is not a build failure
#
# gitlab.com answered 502 mid-run and took the whole pipeline with it. The URL
# was never wrong: the same clone of the same branch succeeds seconds later, and
# what git actually asks for - .git/info/refs?service=git-upload-pack - answers
# 200. A CI runner shares its egress IP with a great many others, which is why
# this is seen there and hardly ever on a workstation.
#
# It keeps trying for TEN MINUTES, not for a fixed number of attempts. The
# asymmetry is the whole point: giving up does not cost the remaining seconds of
# a retry, it costs the entire job from the beginning - plus however long it
# takes a human to notice a red run and decide to press the button. Ten minutes
# of patience here is cheaper than the restart it avoids, and it is time that
# would have been spent waiting anyway.
#
# Backoff 3, 6, 12, 24, 48 then a minute between attempts, so a long outage is
# not hammered and a short one is caught almost at once.
#
# COR_GIT_RETRY_SECONDS overrides the deadline (0 disables retrying entirely).
#
gitRetry()
{
  local label="$1"; shift
  local budget=${COR_GIT_RETRY_SECONDS:-600}
  local deadline=$(( $(date +%s) + budget ))
  local attempt=1 pause=3

  while :; do
    if "$@"; then
      [ "$attempt" -gt 1 ] && echo ">>> $label: succeeded on attempt $attempt"
      return 0
    fi

    local left=$(( deadline - $(date +%s) ))
    if [ "$left" -le 0 ]; then
      local s=s; [ "$attempt" = 1 ] && s=
      echo ">>> $label: giving up after $attempt attempt$s over ${budget}s" >&2
      return 1
    fi

    # Never sleep past the deadline - but do spend what is left of it, so the
    # last attempt happens AT the ten-minute mark rather than a minute short.
    local nap=$pause
    [ "$nap" -gt "$left" ] && nap=$left

    echo ">>> $label: attempt $attempt failed - retrying in ${nap}s (${left}s left)" >&2
    sleep "$nap"
    attempt=$(( attempt + 1 ))
    [ "$pause" -lt 60 ] && pause=$(( pause * 2 ))
    [ "$pause" -gt 60 ] && pause=60
  done
}


#
# cloneFresh <url> <ref> <dir> - clone, from nothing, every time
#
# A clone that dies part way leaves the directory behind, and the next attempt
# would fail on "already exists" rather than on whatever really went wrong. The
# directory is known not to be a repo here (its .git was checked), so removing
# it destroys nothing.
#
cloneFresh()
{
  local url="$1" ref="$2" dir="$3"

  rm -rf "$dir"
  git clone --quiet --branch "$ref" "$url" "$dir"
}


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
    gitRetry "$repo fetch" git -C "$BASE/$repo" fetch --all --quiet
    git -C "$BASE/$repo" checkout --quiet "$ref"
    # A pinned release branch has nothing to pull; main might. Never merge.
    git -C "$BASE/$repo" pull --ff-only --quiet || true
  else
    gitRetry "$repo clone" cloneFresh "$(urlFor "$repo" "$host")" "$ref" "$BASE/$repo"
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
