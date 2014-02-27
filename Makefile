# This is a compatibility Makefile for neovim which is intended to make life
# easier for some older build scripts. Its use is deprecated and it will be
# removed.

build:
	$(MAKE) -C scripts/ build

cmake:
	$(MAKE) -C scripts/ cmake

test:
	$(MAKE) -C scripts/ test

.PHONY: build cmake test
