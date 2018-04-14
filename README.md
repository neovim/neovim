[![Neovim](https://raw.githubusercontent.com/neovim/neovim.github.io/master/logos/neovim-logo-600x173.png)](https://neovim.io)

[Wiki](https://github.com/neovim/neovim/wiki) |
[Documentation](https://neovim.io/doc) |
[Twitter](https://twitter.com/Neovim) |
[Community](https://neovim.io/community/) |
[Gitter **Chat**](https://gitter.im/neovim/neovim)

[![Travis Build Status](https://travis-ci.org/neovim/neovim.svg?branch=master)](https://travis-ci.org/neovim/neovim)
[![AppVeyor Build status](https://ci.appveyor.com/api/projects/status/urdqjrik5u521fac/branch/master?svg=true)](https://ci.appveyor.com/project/neovim/neovim/branch/master)
[![codecov](https://img.shields.io/codecov/c/github/neovim/neovim.svg)](https://codecov.io/gh/neovim/neovim)
[![Coverity Scan Build](https://scan.coverity.com/projects/2227/badge.svg)](https://scan.coverity.com/projects/2227)
[![Clang Scan Build](https://neovim.io/doc/reports/clang/badge.svg)](https://neovim.io/doc/reports/clang)
[![PVS-studio Check](https://neovim.io/doc/reports/pvs/badge.svg)](https://neovim.io/doc/reports/pvs)

[![Debian CI](https://badges.debian.net/badges/debian/testing/neovim/version.svg)](https://buildd.debian.org/neovim)
[![Downloads](https://img.shields.io/github/downloads/neovim/neovim/total.svg?maxAge=2592001)](https://github.com/neovim/neovim/releases/)

Neovim is a project that seeks to aggressively refactor Vim in order to:

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

To install to a non-default location, set `CMAKE_INSTALL_PREFIX`:

    make CMAKE_EXTRA_FLAGS="-DCMAKE_INSTALL_PREFIX=/full/path/"
    make install

To list all targets:

    cmake --build build --target help

See [the wiki](https://github.com/neovim/neovim/wiki/Building-Neovim) for details.

Install from package
--------------------

Pre-built packages for Windows, macOS, and Linux are found at the
[Releases](https://github.com/neovim/neovim/releases/) page.

Managed packages are in [Homebrew], [Debian], [Ubuntu], [Fedora], [Arch Linux], [Gentoo],
and [more](https://github.com/neovim/neovim/wiki/Installing-Neovim)!

Project layout
--------------

    ├─ ci/              build automation
    ├─ cmake/           build scripts
    ├─ runtime/         user plugins/docs
    ├─ src/             application source code (see src/nvim/README.md)
    │  ├─ api/          API subsystem
    │  ├─ eval/         VimL subsystem
    │  ├─ event/        event-loop subsystem
    │  ├─ generators/   code generation (pre-compilation)
    │  ├─ lib/          generic data structures
    │  ├─ lua/          lua subsystem
    │  ├─ msgpack_rpc/  RPC subsystem
    │  ├─ os/           low-level platform code
    │  └─ tui/          built-in UI
    ├─ third-party/     cmake subproject to build dependencies
    └─ test/            tests (see test/README.md)

- To disable `third-party/` specify `USE_BUNDLED_DEPS=NO` or `USE_BUNDLED=NO`
  (CMake option).

Features
--------

- Modern [GUIs](https://github.com/neovim/neovim/wiki/Related-projects#gui)
- [API](https://github.com/neovim/neovim/wiki/Related-projects#api-clients)
  access from any language including clojure, lisp, go, haskell, lua,
  javascript, perl, python, ruby, rust.
- Embedded, scriptable [terminal emulator](https://neovim.io/doc/user/nvim_terminal_emulator.html)
- Asynchronous [job control](https://github.com/neovim/neovim/pull/2247)
- [Shared data (shada)](https://github.com/neovim/neovim/pull/2506) among multiple editor instances
- [XDG base directories](https://github.com/neovim/neovim/pull/3470) support
- Compatible with most Vim plugins, including Ruby and Python plugins.

See [`:help nvim-features`][nvim-features] for the full list!

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
[advanced UIs]: https://github.com/neovim/neovim/wiki/Related-projects#gui
[Homebrew]: https://github.com/neovim/homebrew-neovim#installation
[Debian]: https://packages.debian.org/testing/neovim
[Ubuntu]: http://packages.ubuntu.com/search?keywords=neovim
[Fedora]: https://admin.fedoraproject.org/pkgdb/package/rpms/neovim
[Arch Linux]: https://www.archlinux.org/packages/?q=neovim
[Gentoo]: https://packages.gentoo.org/packages/app-editors/neovim

<!-- vim: set tw=80: -->
