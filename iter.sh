#!/bin/bash
#
# FILE            iter.sh
#
# AUTHOR          Ken Zangelin
#
# Copyright 2026 Seamware
#
# Run a command in each library directory.
# Usage: ./iter.sh <command>
# Example: ./iter.sh "wc -l *.c *.h"
#
ROOT=$(cd "$(dirname "$0")/.." && pwd)

K_DIRS="kbase klog ktrace kalloc kjson khash kprom kargs"
SW_DIRS="swRest swJsonld swPlugin swNgsild"

for dir in $K_DIRS $SW_DIRS; do
  if [ -d "$ROOT/$dir" ]; then
    cd "$ROOT/$dir"
    echo '---------- '$dir' ---------------'
    eval "$@"
    echo
  fi
done
