# neovim ([bountysource fundraiser](https://www.bountysource.com/fundraisers/539-neovim-first-iteration))

[![Build Status](https://travis-ci.org/neovim/neovim.png?branch=master)](https://travis-ci.org/neovim/neovim)
[![Stories in Ready](https://badge.waffle.io/neovim/neovim.png?label=ready)](https://waffle.io/neovim/neovim)

## What's this?

Neovim is a project that seeks to aggressively refactor vim in order to:

- Simplify maintenance
- Split the work between multiple developers
- Enable the implementation of new/modern user interfaces without any
  modifications to the core source
- Improve extensibility with a new plugin architecture

For lots more details, see
[the wiki](https://github.com/neovim/neovim/wiki/Introduction)!

## What's been done so far

- Source tree was cleaned up, leaving only files necessary for
  compilation/testing of the core
- Source files were processed with [unifdef][] to remove tons of `FEAT_*`
  macros
- Files were processed with [uncrustify][] to normalize source code
  formatting
- The autotools build system was replaced by [CMake][]

[unifdef]: http://freecode.com/projects/unifdef
[uncrustify]: http://uncrustify.sourceforge.net/
[CMake]: http://cmake.org/

## What's being worked on now

- Porting all IO to libuv
- Lots of refactoring
- A VimL -> Lua transpiler

## How do I get it?

There is a formula for OSX/homebrew, a PKGBUILD for Arch Linux,
and detailed instructions for building on other OSes.

See [the wiki](https://github.com/neovim/neovim/wiki/Installing)!

## Community

Join the community on IRC in #neovim on Freenode or the [mailing list](https://groups.google.com/forum/#!forum/neovim)

## Contributing

...would be awesome! See [the wiki](https://github.com/neovim/neovim/wiki/Contributing) for more details.

## License

Vim itself is distributed under the terms of the Vim License.
See vim-license.txt for details.

Vim also includes a message along the following lines:

    Vim is Charityware.  You can use and copy it as much as you like, but you are
    encouraged to make a donation for needy children in Uganda.  Please see the
    kcc section of the vim docs or visit the ICCF web site, available at these URLs:

            http://iccf-holland.org/
            http://www.vim.org/iccf/
            http://www.iccf.nl/

    You can also sponsor the development of Vim.  Vim sponsors can vote for
    features.  The money goes to Uganda anyway.

<!-- vim: set tw=80: -->
