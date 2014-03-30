# Neovim ([bountysource fundraiser](https://www.bountysource.com/fundraisers/539-neovim-first-iteration))

[![Build Status](https://travis-ci.org/neovim/neovim.png?branch=master)](https://travis-ci.org/neovim/neovim)
[![Stories in Ready](https://badge.waffle.io/neovim/neovim.png?label=ready)](https://waffle.io/neovim/neovim)
[![Coverage Status](https://coveralls.io/repos/neovim/neovim/badge.png)](https://coveralls.io/r/neovim/neovim)

Neovim is a project that seeks to aggressively refactor Vim in order to:

- Simplify maintenance and encourage contributions
- Split the work between multiple developers
- Enable the implementation of new/modern user interfaces without any
  modifications to the core source
- Improve extensibility with a new plugin architecture

For lots more details, see
[the wiki](https://github.com/neovim/neovim/wiki/Introduction)!

### What's been done so far

- Cleaned up source tree, leaving only core files
- Removed support for legacy systems and moved to C99
    - Removed tons of `FEAT_*` macros with [unifdef]
    - Reduced C code from 300k lines to 170k
- Enabled modern compiler features and [optimizations](https://github.com/neovim/neovim/pull/426)
- Formatted entire source with [uncrustify]
- Replaced autotools build system with [CMake]
- Implemented [continuous integration] and [test coverage]
- Wrote 60+ new unit tests
- Split large, monolithic files (`misc1.c`) into logical units
  (`path.c`, `indent.c`, `garray.c`, `keymap.c`, ...)

[unifdef]: http://freecode.com/projects/unifdef
[uncrustify]: http://uncrustify.sourceforge.net/
[CMake]: http://cmake.org/
[continuous integration]: https://travis-ci.org/neovim/neovim
[test coverage]: https://coveralls.io/r/neovim/neovim

### What's being worked on now

- Porting all IO to libuv
- Lots of refactoring
- A VimL => Lua transpiler
- Formatting with `clint.py`

### How do I get it?

There is a formula for OSX/homebrew, a PKGBUILD for Arch Linux,
and detailed instructions for building on other OSes.

See [the wiki](https://github.com/neovim/neovim/wiki/Installing)!

### Community

Join the community on IRC in #neovim on Freenode or the [mailing list](https://groups.google.com/forum/#!forum/neovim)

### Contributing

...would be awesome! See [the wiki](https://github.com/neovim/neovim/wiki/Contributing) for more details.

### License

Vim itself is distributed under the terms of the Vim License.
See vim-license.txt for details.

Vim also includes this message:

    Vim is Charityware.  You can use and copy it as much as you like, but you are
    encouraged to make a donation for needy children in Uganda.  Please see the
    kcc section of the vim docs or visit the ICCF web site, available at these URLs:

            http://iccf-holland.org/
            http://www.vim.org/iccf/
            http://www.iccf.nl/

    You can also sponsor the development of Vim.  Vim sponsors can vote for
    features.  The money goes to Uganda anyway.

<!-- vim: set tw=80: -->
