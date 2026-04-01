#
# FILE            makefile
#
# AUTHOR          Ken Zangelin
#
# Copyright 2026 Seamware
#
# Umbrella makefile for all k-libs and sw-libs.
# Libraries live under ~/git as separate repos.
# Build order respects dependencies.
#
ROOT = $(HOME)/git

# k-libs (foundation, no sw-lib dependencies)
K_DIRS = kbase klog ktrace kalloc kjson khash kprom kargs

# sw-libs (depend on k-libs and each other)
SW_DIRS = swRest swJsonld swPlugin swNgsild

DIRS = $(K_DIRS) $(SW_DIRS)

SWLIBS_HOME = $(ROOT)/swLibs
BIN_DIR     = $(SWLIBS_HOME)/bin
LIB_DIR     = $(SWLIBS_HOME)/lib

all install clean ci cdi di i debug:
	@for dir in $(DIRS); do echo "=== $$dir: $@ ===" && $(MAKE) -C $(ROOT)/$$dir $@ || exit 1; done
	@$(MAKE) --no-print-directory install-local

install-local:
	@mkdir -p $(BIN_DIR) $(LIB_DIR)
	@cat $(ROOT)/swTest/swTest > $(BIN_DIR)/swTest && chmod +x $(BIN_DIR)/swTest
	@cat $(ROOT)/swTest/swTestFunctions.sh > $(BIN_DIR)/swTestFunctions.sh
	@cat $(ROOT)/swTest/swDiff > $(BIN_DIR)/swDiff && chmod +x $(BIN_DIR)/swDiff
	@cat $(ROOT)/swTest/swDiffGui > $(BIN_DIR)/swDiffGui && chmod +x $(BIN_DIR)/swDiffGui
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
	@echo "  sw-libs: $(SW_DIRS)"
