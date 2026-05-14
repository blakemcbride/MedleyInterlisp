# Top-level Makefile for MedleyInterlisp
#
# Builds the Maiko VM and the Lisp sysouts. See BUILD.md for prerequisites.

OS_VER  := $(shell sh maiko/bin/osversion)
MACHINE := $(shell sh maiko/bin/machinetype)
MAIKO_BINDIR := maiko/$(OS_VER).$(MACHINE)

CMAKE_BUILD_DIR := maiko/build
LOADUPS_DIR := medley/loadups
LOADUPS_BUILD_DIR := $(LOADUPS_DIR)/build

# Cygwin-only: scrub Strawberry Perl and Chocolatey out of PATH, then put
# Cygwin's /usr/local/bin and /usr/bin first, and pin CMake's make program
# to Cygwin's make. Without this, CMake may pick up Windows-native binaries
# from $PATH (e.g. Strawberry Perl's gmake at
# /cygdrive/c/Strawberry/c/bin/gmake) and generate Makefiles with mixed
# Cygwin/Windows path styles. The Windows port depends only on Cygwin.
# No effect on Linux or macOS.
CMAKE_EXTRA_ARGS :=
ifneq ($(findstring CYGWIN,$(shell uname -s 2>/dev/null)),)
  CYGWIN_SAFE_PATH := $(shell echo "$$PATH" | tr ':' '\n' | grep -ivE 'strawberry|chocolatey' | paste -sd: -)
  export PATH := /usr/local/bin:/usr/bin:$(CYGWIN_SAFE_PATH)
  CMAKE_EXTRA_ARGS := -DCMAKE_MAKE_PROGRAM=$(shell command -v make)
endif

.PHONY: all maiko sysouts apps aux db clean realclean help

all: maiko sysouts

help:
	@echo "Targets:"
	@echo "  all        Build Maiko and the lisp/full sysouts (default)"
	@echo "  maiko      Build the Maiko VM only"
	@echo "  sysouts    Build lisp.sysout and full.sysout (depends on maiko)"
	@echo "  apps       Also build apps.sysout (requires ../notecards repo)"
	@echo "  aux        Rebuild exports.all and whereis.hash"
	@echo "  db         Build the Masterscope database (fuller.database)"
	@echo "  clean      Remove intermediate build files; keep runnable system"
	@echo "  realclean  clean, plus remove every built artifact"
	@echo "  help       Show this message"

maiko:
	cmake -S maiko -B $(CMAKE_BUILD_DIR) $(CMAKE_EXTRA_ARGS)
	cmake --build $(CMAKE_BUILD_DIR)
	cmake --install $(CMAKE_BUILD_DIR)

# Invoke the real loadup script by path rather than via the medley/loadup
# symlink. Git for Windows checks symlinks out as plain text files when
# core.symlinks is false (the default), which breaks ./loadup on Cygwin.
# This is a no-op on Linux/macOS — same script, same CWD.
sysouts: maiko
	cd medley && ./scripts/loadups/loadup

apps: maiko
	cd medley && ./scripts/loadups/loadup -apps

aux: maiko
	cd medley && ./scripts/loadups/loadup-aux.sh

db: maiko
	cd medley && ./scripts/loadups/loadup-db.sh

clean:
	rm -rf $(CMAKE_BUILD_DIR)
	rm -rf $(LOADUPS_BUILD_DIR)
	rm -f $(LOADUPS_DIR)/*.dribble
	rm -f $(LOADUPS_DIR)/lock
	rm -rf medley/tmp

realclean: clean
	rm -rf $(MAIKO_BINDIR)
	rm -f $(LOADUPS_DIR)/*.sysout
	rm -f $(LOADUPS_DIR)/exports.all
	rm -f $(LOADUPS_DIR)/whereis.hash
	rm -f $(LOADUPS_DIR)/fuller.database
	rm -f $(LOADUPS_DIR)/gitinfo
