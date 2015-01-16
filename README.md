![Neovim](https://raw.githubusercontent.com/neovim/neovim.github.io/master/logos/neovim-logo.png)

[Website](http://neovim.org) |
[Wiki](https://github.com/neovim/neovim/wiki) |
[Documentation](http://neovim.org/doc) |
[Mailing List](https://groups.google.com/forum/#!forum/neovim) |
[Twitter](http://twitter.com/Neovim) |
[Reddit](http://www.reddit.com/r/neovim) |
[Bountysource](https://www.bountysource.com/teams/neovim)

[![Build Status](https://travis-ci.org/neovim/neovim.svg?branch=master)](https://travis-ci.org/neovim/neovim)
[![Pull requests waiting for review](https://badge.waffle.io/neovim/neovim.svg?label=RFC&title=RFCs)](https://waffle.io/neovim/neovim)
[![Coverage Status](https://img.shields.io/coveralls/neovim/neovim.svg)](https://coveralls.io/r/neovim/neovim)
[![Coverity Scan Build](https://scan.coverity.com/projects/2227/badge.svg)](https://scan.coverity.com/projects/2227)
[![Clang Scan Build](http://neovim.org/doc/reports/clang/badge.svg)](http://neovim.org/doc/reports/clang)

Neovim is a project that seeks to aggressively refactor Vim in order to:

- Simplify maintenance and encourage [contributions](https://github.com/neovim/neovim/wiki/Contributing)
- Split the work between multiple developers
- Enable the implementation of new/modern user interfaces without any
  modifications to the core source
- Improve extensibility with a new [plugin architecture](https://github.com/neovim/neovim/wiki/Plugin-UI-architecture)

For lots more details, see
[the wiki](https://github.com/neovim/neovim/wiki/Introduction)!

### What's been done so far

- [Job control](https://github.com/neovim/neovim/pull/475) (work with processes asynchronously)
- msgpack remote API
- Performance, reliability, and portability improvements
- See the [progress page](https://github.com/neovim/neovim/wiki/Progress) for a comprehensive list.

[![Throughput Graph](https://graphs.waffle.io/neovim/neovim/throughput.svg)](https://waffle.io/neovim/neovim/metrics)

### What's being worked on now

- Port all IO to [libuv](https://github.com/libuv/libuv/blob/master/README.md)
- Lots of refactoring
- A VimL => Lua transpiler

### How do I get it?

There is a formula for OSX/homebrew, a PKGBUILD for Arch Linux, RPM, deb, and
more. See [the wiki](https://github.com/neovim/neovim/wiki/Installing)!

### Community

Join the community on IRC in #neovim on Freenode or the [mailing list](https://groups.google.com/forum/#!forum/neovim)

### Contributing

...would be awesome! See [the wiki](https://github.com/neovim/neovim/wiki/Contributing) for more details.

### License

Neovim is licensed under the terms of the Apache 2.0 license, except for
parts that were contributed under the Vim license.

- Contributions committed before [b17d96][license-commit] by authors who did
  not sign the Contributor License Agreement (CLA) remain under the Vim license.

- Contributions committed after [b17d96][license-commit] are licensed under
  Apache 2.0 unless those contributions were copied from Vim (identified in 
  the commit logs by the `vim-patch` token).

See `LICENSE` for details.

    Vim is Charityware.  You can use and copy it as much as you like, but you are
    encouraged to make a donation for needy children in Uganda.  Please see the
    kcc section of the vim docs or visit the ICCF web site, available at these URLs:

            http://iccf-holland.org/
            http://www.vim.org/iccf/
            http://www.iccf.nl/

    You can also sponsor the development of Vim.  Vim sponsors can vote for
    features.  The money goes to Uganda anyway.

[license-commit]: https://github.com/neovim/neovim/commit/b17d9691a24099c9210289f16afb1a498a89d803

<!-- vim: set tw=80: -->
