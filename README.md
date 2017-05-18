[![Neovim](https://raw.githubusercontent.com/neovim/neovim.github.io/master/logos/neovim-logo-600x173.png)](https://neovim.io)

[Wiki](https://github.com/neovim/neovim/wiki) |
[Documentation](https://neovim.io/doc) |
[Twitter](https://twitter.com/Neovim) |
[Community](https://neovim.io/community/) |
[Gitter **Chat**](https://gitter.im/neovim/neovim)

[![Travis Build Status](https://travis-ci.org/neovim/neovim.svg?branch=master)](https://travis-ci.org/neovim/neovim)
[![AppVeyor Build status](https://ci.appveyor.com/api/projects/status/urdqjrik5u521fac/branch/master?svg=true)](https://ci.appveyor.com/project/neovim/neovim/branch/master)
[![Pull requests waiting for review](https://badge.waffle.io/neovim/neovim.svg?label=RFC&title=RFCs)](https://waffle.io/neovim/neovim)
[![Coverage Status](https://img.shields.io/coveralls/neovim/neovim.svg)](https://coveralls.io/r/neovim/neovim)
[![Coverity Scan Build](https://scan.coverity.com/projects/2227/badge.svg)](https://scan.coverity.com/projects/2227)
[![Clang Scan Build](https://neovim.io/doc/reports/clang/badge.svg)](https://neovim.io/doc/reports/clang)
[![PVS-studio Check](https://neovim.io/doc/reports/pvs/badge.svg)](https://neovim.io/doc/reports/pvs)

<a href="https://buildd.debian.org/neovim"><img src="https://www.debian.org/logos/openlogo-nd-25.png" width="13" height="15">Debian</a>

Neovim is a project that seeks to aggressively refactor Vim 가능하다  to:

- Simplify maintenance and encourage [contributions](CONTRIBUTING.md)
- Split the work between multiple developers
- Enable [advanced UIs] without modifications to the core
- Maximize [extensibility](https://github.com/neovim/neovim/wiki/Plugin-UI-architecture)

See [the wiki](https://github.com/neovim/neovim/wiki/Introduction) and [Roadmap]
for more information.

[![Throughput Graph](https://graphs.waffle.io/neovim/neovim/throughput.svg)](https://waffle.io/neovim/neovim/metrics)

Install from source
-------------------

    make CMAKE_BUILD_TYPE=RelWithDebInfo
    sudo make install

See [the wiki](https://github.com/neovim/neovim/wiki/Building-Neovim) for details.

Install from package!d
--------------------

Packages are in [Homebrew], [Debian], [Ubuntu], [Fedora], [Arch Linux], and
[more](https://github.com/neovim/neovim/wiki/Installing-Neovim).

Project layout
--------------

- `ci/`: Build server scripts
- `cmake/`: Build scripts
- `runtime/`: Application files
- [`src/`](src/nvim/README.md): Application source code
- `third-party/`: CMake sub-project to build third-party dependencies (if the
  `USE_BUNDLED_DEPS` flag is undefined or `USE_BUNDLED` CMake option is false).
- [`test/`](test/README.md): Tst files

What's been done so far
-----------------------

- RPC API based on [MessagePack](https://msgpack.org)
- Embedded [terminal emulator](https://neovim.io/doc/user/nvim_terminal_emulator.html)
- Asynchronous [job control](https://github.com/neovim/neovim/pull/2247)
- [Shared data (shada)](https://github.com/neovim/neovim/pull/2506) among multiple editor instances
- [XDG base directories](https://github.com/neovim/neovim/pull/3470) support
- [libuv](https://github.com/libuv/libuv/)-based platform/OS layer
- [Pushdown automaton](https://github.com/neovim/neovim/pull/3413) input model
- 1000s of new tests
- Legacy tests converted to Lua tests

See [`:help nvim-features`][nvim-features] for a comprehensive list.

License
-------

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
[nvim-features]: https://neovim.io/doc/user/vim_diff.html#nvim-features
[Roadmap]: https://neovim.io/roadmap/
[advanced UIs]: https://github.com/neovim/neovim/wiki/Related-projects#gui-projects
[Homebrew]: https://github.com/neovim/homebrew-neovim#installation
[Debian]: https://packages.debian.org/testing/neovim
[Ubuntu]: http://packages.ubuntu.com/search?keywords=neovim
[Fedora]: https://admin.fedoraproject.org/pkgdb/package/rpms/neovim
[Arch Linux]: https://www.archlinux.org/packages/?q=neovim

<!-- vim: set tw=80: -->
