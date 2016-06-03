![Neovim](https://raw.githubusercontent.com/neovim/neovim.github.io/master/logos/neovim-logo.png)

[Website](http://neovim.io) |
[Community](http://neovim.io/community/) |
[Wiki](https://github.com/neovim/neovim/wiki) |
[Documentation](http://neovim.io/doc) |
[Mailing List](https://groups.google.com/forum/#!forum/neovim) |
[Twitter](http://twitter.com/Neovim) |
[Bountysource](https://www.bountysource.com/teams/neovim)

[![Travis Build Status](https://travis-ci.org/neovim/neovim.svg?branch=master)](https://travis-ci.org/neovim/neovim)
[![AppVeyor Build status](https://ci.appveyor.com/api/projects/status/cf1jwc29198748we/branch/master?svg=true)](https://ci.appveyor.com/project/neovim/neovim/branch/master)
[![Pull requests waiting for review](https://badge.waffle.io/neovim/neovim.svg?label=RFC&title=RFCs)](https://waffle.io/neovim/neovim)
[![Coverage Status](https://img.shields.io/coveralls/neovim/neovim.svg)](https://coveralls.io/r/neovim/neovim)
[![Coverity Scan Build](https://scan.coverity.com/projects/2227/badge.svg)](https://scan.coverity.com/projects/2227)
[![Clang Scan Build](http://neovim.io/doc/reports/clang/badge.svg)](http://neovim.io/doc/reports/clang)
[![Join the chat at https://gitter.im/neovim/neovim](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/neovim/neovim?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

Neovim is a project that seeks to aggressively refactor Vim in order to:

- Simplify maintenance and encourage [contributions](CONTRIBUTING.md)
- Split the work between multiple developers
- Enable the implementation of new/modern user interfaces without any
  modifications to the core source
- Improve extensibility with a new [plugin architecture](https://github.com/neovim/neovim/wiki/Plugin-UI-architecture)

For lots more details, see
[the wiki](https://github.com/neovim/neovim/wiki/Introduction)!

### What's been done so far

- Automatic [history merge](https://github.com/neovim/neovim/pull/2506) between multiple editor instances
- [XDG-compliant](https://github.com/neovim/neovim/pull/3470) configuration
- Embedded [terminal emulator](https://neovim.io/doc/user/nvim_terminal_emulator.html)
- Asynchronous [job control](https://github.com/neovim/neovim/pull/2247)
- [MessagePack](https://msgpack.org) remote API
- [Pushdown automaton](https://github.com/neovim/neovim/pull/3413) for state transitions

See the [progress page](https://github.com/neovim/neovim/wiki/Progress) for a comprehensive list.

[![Throughput Graph](https://graphs.waffle.io/neovim/neovim/throughput.svg)](https://waffle.io/neovim/neovim/metrics)

### What's being worked on now

- Port all IO to [libuv](https://github.com/libuv/libuv/)
- Convert legacy tests to Lua tests
- VimL => Lua translator

### How do I get it?

There is a formula for OSX/homebrew, a PKGBUILD for Arch Linux, RPM, deb, and
more. See [the wiki](https://github.com/neovim/neovim/wiki/Installing-Neovim)!

### License

Neovim is licensed under the terms of the Apache 2.0 license, except for
parts that were contributed under the Vim license.

- Contributions committed before [b17d96][license-commit] remain under the Vim
  license.

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
