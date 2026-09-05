#
# FILE            makefile
#
# AUTHOR          Ken Zangelin
#
# Copyright 2026 Seamware
# SPDX-License-Identifier: Apache-2.0
#
# Umbrella makefile for all k-libs and Cor-Libs.
# Every library is a separate repo, and they are SIBLINGS of this one - the
# include paths and CMake references all resolve as ../<name>, so the layout is
# part of the build contract.
#
# ROOT is therefore derived from where this makefile actually sits, not from a
# fixed path: a checkout under any directory builds itself, which is what lets
# CI (where there is no ~/git) use the same recipe as a workstation. Override
# it explicitly if you ever need to point somewhere else.
#
ROOT ?= $(abspath $(dir $(lastword $(MAKEFILE_LIST)))..)

# k-libs (foundation, no Cor-Lib dependencies)
K_DIRS = kbase klog ktrace kalloc kjson khash kprom kargs

#
# Cor-Libs (depend on k-libs and each other)
#
# corHttp comes FIRST: corRest links it when built with COR_HTTP_SERVER=builtin,
# and this loop is ordered.
#
COR_DIRS = corHttp corRest corJsonld corPlugin corNgsild

DIRS = $(K_DIRS) $(COR_DIRS)

CORLIBS_HOME = $(ROOT)/corLibs
BIN_DIR     = $(CORLIBS_HOME)/bin
LIB_DIR     = $(CORLIBS_HOME)/lib

all install clean ci cdi di i debug:
	@for dir in $(DIRS); do echo "=== $$dir: $@ ===" && $(MAKE) -C $(ROOT)/$$dir $@ || exit 1; done
	@$(MAKE) --no-print-directory install-local

install-local:
	@mkdir -p $(BIN_DIR) $(LIB_DIR)
	@cat $(ROOT)/corTest/corTest > $(BIN_DIR)/corTest && chmod +x $(BIN_DIR)/corTest
	@cat $(ROOT)/corTest/corTestFunctions.sh > $(BIN_DIR)/corTestFunctions.sh
	@cat $(ROOT)/corTest/corDiff > $(BIN_DIR)/corDiff && chmod +x $(BIN_DIR)/corDiff
	@cat $(ROOT)/corTest/corDiffGui > $(BIN_DIR)/corDiffGui && chmod +x $(BIN_DIR)/corDiffGui
#
# kjson belongs beside corTest, not merely near it. corCurl pipes every JSON
# response through `kjson -sort` before comparison - member order is insertion
# order and none of a test's business - and every expect in every suite was
# captured that way. A corTest without a kjson is a corTest that fails 611 of 612
# tests on member order, which is precisely what CI did before this line existed.
# Having one now implies having the other: one directory on PATH, both tools.
#
	@if [ -x $(ROOT)/kjson/bin/kjson ]; then 	   cat $(ROOT)/kjson/bin/kjson > $(BIN_DIR)/kjson && chmod +x $(BIN_DIR)/kjson; 	 else 	   echo "WARNING: $(ROOT)/kjson/bin/kjson not built - corTest will refuse to run"; 	 fi
	@for dir in $(DIRS); do \
	  for f in $(ROOT)/$$dir/lib*.so $(ROOT)/$$dir/lib*.a; do \
	    [ -f "$$f" ] && cat "$$f" > $(LIB_DIR)/$$(basename "$$f"); \
	  done; \
	done
	@echo "Installed: bin/ lib/"

test:
	@total=0; errors=0; \
	for dir in $(DIRS); do \
	  if ! grep -q '^test:' $(ROOT)/$$dir/makefile 2>/dev/null; then \
	    printf "%-12s 0 test cases, 0 errors\n" "$$dir:"; \
	    continue; \
	  fi; \
	  output=$$($(MAKE) -C $(ROOT)/$$dir test 2>&1); \
	  rc=$$?; \
	  t=0; e=0; \
	  if echo "$$output" | grep -q "No tests yet"; then \
	    t=0; e=0; \
	  elif n=$$(echo "$$output" | grep -oP 'All \K\d+(?= tests passed)'); then \
	    t=$$n; e=0; \
	  elif line=$$(echo "$$output" | grep -oP '\d+/\d+ tests failed'); then \
	    e=$$(echo "$$line" | grep -oP '^\d+'); \
	    t=$$(echo "$$line" | grep -oP '/\K\d+'); \
	  elif line=$$(echo "$$output" | grep -oP '\d+ tests?, \d+ failures?'); then \
	    t=$$(echo "$$line" | grep -oP '^\d+'); \
	    e=$$(echo "$$line" | grep -oP ', \K\d+'); \
	  elif [ $$rc -ne 0 ]; then \
	    e=1; \
	  fi; \
	  total=$$((total + t)); errors=$$((errors + e)); \
	  if [ $$e -gt 0 ]; then \
	    printf "\033[0;31m%-12s %d test cases, %d errors\033[0m\n" "$$dir:" $$t $$e; \
	  else \
	    printf "%-12s %d test cases, %d errors\n" "$$dir:" $$t $$e; \
	  fi; \
	done; \
	echo ""; \
	if [ $$errors -gt 0 ]; then \
	  printf "\033[0;31mTotal: %d test cases, %d errors\033[0m\n" $$total $$errors; \
	  exit 1; \
	else \
	  printf "\033[0;32mTotal: %d test cases, 0 errors\033[0m\n" $$total; \
	fi

gs:
	@for dir in $(DIRS); do \
	  if [ -d $(ROOT)/$$dir/.git ]; then \
	    echo "=== $$dir: $$(git -C $(ROOT)/$$dir branch --show-current 2>/dev/null) ===" && git -C $(ROOT)/$$dir status -s && echo; \
	  else \
	    echo "=== $$dir: (not a git repo) ==="; echo; \
	  fi; \
	done

branch:
	@for dir in $(DIRS); do \
	  if [ -d $(ROOT)/$$dir/.git ]; then \
	    printf "%-12s %s\n" "$$dir:" $$(git -C $(ROOT)/$$dir branch --show-current 2>/dev/null); \
	  else \
	    printf "%-12s %s\n" "$$dir:" "(no git)"; \
	  fi; \
	done

pull:
	@for dir in $(DIRS); do \
	  if [ -d $(ROOT)/$$dir/.git ]; then \
	    echo "=== $$dir ===" && git -C $(ROOT)/$$dir pull origin $$(git -C $(ROOT)/$$dir branch --show-current) && echo; \
	  fi; \
	done

help:
	@echo "make all       - build all libraries (release)"
	@echo "make debug     - build all libraries (debug)"
	@echo "make install   - build and install headers + libs"
	@echo "make ci        - clean + install"
	@echo "make di        - debug + install"
	@echo "make cdi       - clean + debug + install"
	@echo "make clean     - clean all libraries"
	@echo "make test      - run all test suites"
	@echo "make gs        - git status across all libraries"
	@echo "make branch    - show current branch per library"
	@echo "make pull      - git pull in all libraries"
	@echo "make help      - show this help"
	@echo ""
	@echo "Libraries under $(ROOT):"
	@echo "  k-libs: $(K_DIRS)"
	@echo "  Cor-Libs: $(COR_DIRS)"
