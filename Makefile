# Development helper — same verbs as c-codingbat/build, via CMake presets.
#   make                  debug build (default)
#   make build release
#   make test
#   make run
#   make clean

ifneq ($(wildcard /opt/homebrew/bin),)
export PATH := /opt/homebrew/bin:$(PATH)
endif

PRESET ?= debug

ifneq ($(filter release,$(MAKECMDGOALS)),)
PRESET := release
endif
ifneq ($(filter debug,$(MAKECMDGOALS)),)
PRESET := debug
endif

BUILD_DIR = build/$(PRESET)
APP = $(BUILD_DIR)/DeepCleanMyMac.app
TESTS = $(BUILD_DIR)/dcmm-desktop-tests

.PHONY: all build debug release test run open relaunch clean help init

.DEFAULT_GOAL := build

debug release:
	@:

all:
	$(MAKE) build PRESET=debug
	$(MAKE) build PRESET=release

init:
	git submodule update --init extras/dcmmlib

build:
	@if [ ! -f extras/dcmmlib/CMakeLists.txt ]; then \
		echo "extras/dcmmlib missing — run: make init"; exit 1; \
	fi
	cmake --preset $(PRESET)
	cmake --build --preset $(PRESET)

test: build
	ctest --preset $(PRESET) --output-on-failure

run: build
	open "$(APP)"

open: run

relaunch: build
	-pkill -x DeepCleanMyMac
	open "$(APP)"

clean:
ifeq ($(filter debug,$(MAKECMDGOALS)),debug)
	rm -rf build/debug
	@echo "Cleaned debug build."
else ifeq ($(filter release,$(MAKECMDGOALS)),release)
	rm -rf build/release
	@echo "Cleaned release build."
else
	rm -rf build
	@echo "Cleaned all build directories."
endif

help:
	@echo "Usage: make [build | run | test | clean | relaunch | init | help] [debug | release | all]"
	@echo
	@echo "  make                 build debug (default)"
	@echo "  make build           build debug"
	@echo "  make build release   build release"
	@echo "  make all             build debug and release"
	@echo "  make test            build + ctest (debug)"
	@echo "  make test release    build + ctest (release)"
	@echo "  make run             build and open DeepCleanMyMac.app"
	@echo "  make run release     same, release preset"
	@echo "  make relaunch        pkill + open (after UI changes)"
	@echo "  make clean           remove build/"
	@echo "  make clean debug     remove build/debug"
	@echo "  make init            git submodule update --init extras/dcmmlib"
	@echo
	@echo "PRESET=$(PRESET)  APP=$(APP)"
