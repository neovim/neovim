[![Neovim](https://raw.githubusercontent.com/neovim/neovim.github.io/master/logos/neovim-logo-300x87.png)](https://neovim.io)

[Wiki](https://github.com/neovim/neovim/wiki) |
[Documentation](https://neovim.io/doc) |
[Chat/Discussion](https://gitter.im/neovim/neovim) |
[Twitter](https://twitter.com/Neovim)

[![Travis build status](https://travis-ci.org/neovim/neovim.svg?branch=master)](https://travis-ci.org/neovim/neovim)
[![AppVeyor build status](https://ci.appveyor.com/api/projects/status/urdqjrik5u521fac/branch/master?svg=true)](https://ci.appveyor.com/project/neovim/neovim/branch/master)
[![Codecov coverage](https://img.shields.io/codecov/c/github/neovim/neovim.svg)](https://codecov.io/gh/neovim/neovim)
[![Coverity Scan analysis](https://scan.coverity.com/projects/2227/badge.svg)](https://scan.coverity.com/projects/2227)
[![Clang analysis](https://neovim.io/doc/reports/clang/badge.svg)](https://neovim.io/doc/reports/clang)
[![PVS-Studio analysis](https://neovim.io/doc/reports/pvs/badge.svg)](https://neovim.io/doc/reports/pvs/PVS-studio.html.d)

[![Packages](https://repology.org/badge/tiny-repos/neovim.svg)](https://repology.org/metapackage/neovim)
[![Debian CI](https://badges.debian.net/badges/debian/testing/neovim/version.svg)](https://buildd.debian.org/neovim)
[![Downloads](https://img.shields.io/github/downloads/neovim/neovim/total.svg?maxAge=2592001)](https://github.com/neovim/neovim/releases/)

Neovim is a project that seeks to aggressively refactor Vim in order to:

- Simplify maintenance and encourage [contributions](CONTRIBUTING.md)
- Split the work between multiple developers
- Enable [advanced UIs] without modifications to the core
- Maximize [extensibility](https://github.com/neovim/neovim/wiki/Plugin-UI-architecture)

See the [Introduction](https://github.com/neovim/neovim/wiki/Introduction) wiki page and [Roadmap]
for more information.

Features
--------

- Modern [GUIs](https://github.com/neovim/neovim/wiki/Related-projects#gui)
- [API access](https://github.com/neovim/neovim/wiki/Related-projects#api-clients)
  from any language including C/C++, C#, Clojure, D, Elixir, Go, Haskell, Java,
  JavaScript/Node.js, Julia, Lisp, Lua, Perl, Python, Racket, Ruby, Rust
- Embedded, scriptable [terminal emulator](https://neovim.io/doc/user/nvim_terminal_emulator.html)
- Asynchronous [job control](https://github.com/neovim/neovim/pull/2247)
- [Shared data (shada)](https://github.com/neovim/neovim/pull/2506) among multiple editor instances
- [XDG base directories](https://github.com/neovim/neovim/pull/3470) support
- Compatible with most Vim plugins, including Ruby and Python plugins

See [`:help nvim-features`][nvim-features] for the full list!

Install from package
--------------------

Pre-built packages for Windows, macOS, and Linux are found on the
[Releases](https://github.com/neovim/neovim/releases/) page.

[Managed packages] are in Homebrew, [Debian], [Ubuntu], [Fedora], [Arch Linux],
[Gentoo], and more!

Install from source
-------------------

The build is CMake-based, but a Makefile is provided as a convenience.

    make CMAKE_BUILD_TYPE=RelWithDebInfo
    sudo make install

To install to a non-default location:

    make CMAKE_INSTALL_PREFIX=/full/path/
    make install

To skip bundled (`third-party/*`) dependencies:

1. Install the dependencies using a package manager.
   ```
   sudo apt install gperf luajit luarocks libuv1-dev libluajit-5.1-dev libunibilium-dev libmsgpack-dev libtermkey-dev libvterm-dev libutf8proc-dev
   sudo luarocks build mpack
   sudo luarocks build lpeg
   sudo luarocks build inspect
   ```
2. Build with `USE_BUNDLED=OFF`:
   ```
   make CMAKE_BUILD_TYPE=RelWithDebInfo USE_BUNDLED=OFF
   sudo make install
   ```

To inspect the build, these CMake features are useful:

- `cmake --build build --target help` lists all build targets.
- `build/CMakeCache.txt` (or `cmake -LAH build/`) contains the resolved values of all CMake variables.
- `build/compile_commands.json` shows the full compiler invocations for each translation unit.

See the [Building Neovim](https://github.com/neovim/neovim/wiki/Building-Neovim) wiki page for details.

Transitioning from Vim
--------------------

See [`:help nvim-from-vim`](https://neovim.io/doc/user/nvim.html#nvim-from-vim) for instructions.

Project layout
--------------

    ├─ ci/              build automation
    ├─ cmake/           build scripts
    ├─ runtime/         user plugins/docs
    ├─ src/nvim/        application source code (see src/nvim/README.md)
    │  ├─ api/          API subsystem
    │  ├─ eval/         VimL subsystem
    │  ├─ event/        event-loop subsystem
    │  ├─ generators/   code generation (pre-compilation)
    │  ├─ lib/          generic data structures
    │  ├─ lua/          Lua subsystem
    │  ├─ msgpack_rpc/  RPC subsystem
    │  ├─ os/           low-level platform code
    │  └─ tui/          built-in UI
    ├─ third-party/     CMake subproject to build dependencies
    └─ test/            tests (see test/README.md)

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
[Managed packages]: https://github.com/neovim/neovim/wiki/Installing-Neovim#install-from-package
[Debian]: https://packages.debian.org/testing/neovim
[Ubuntu]: http://packages.ubuntu.com/search?keywords=neovim
[Fedora]: https://apps.fedoraproject.org/packages/neovim
[Arch Linux]: https://www.archlinux.org/packages/?q=neovim
[Gentoo]: https://packages.gentoo.org/packages/app-editors/neovim

<!-- vim: set tw=80: -->
