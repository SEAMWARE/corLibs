#!/bin/bash
#
# FILE            iter.sh
#
# AUTHOR          Ken Zangelin
#
# Copyright 2026 Seamware
# SPDX-License-Identifier: Apache-2.0
#
# Run a command in each library directory.
# Usage: ./iter.sh <command>
# Example: ./iter.sh "wc -l *.c *.h"
#
ROOT=$(cd "$(dirname "$0")/.." && pwd)

#
# The library list comes from the makefile, which is the one that decides it.
# This script used to keep its own copy and it drifted: it still named klog long
# after klog left the stack, and it never learned about corHttp - so `./iter.sh`
# silently skipped a library and silently looked for one that is not there. The
# `-d` guard below is what made it quiet.
#
DIRS=$(sed -n 's/^K_DIRS *= *//p; s/^COR_DIRS *= *//p' "$ROOT/corLibs/makefile")
if [ -z "$DIRS" ]; then
  echo "iter.sh: could not read K_DIRS/COR_DIRS from corLibs/makefile" >&2
  exit 1
fi

for dir in $DIRS; do
  if [ -d "$ROOT/$dir" ]; then
    cd "$ROOT/$dir"
    echo '---------- '$dir' ---------------'
    eval "$@"
    echo
  fi
done
