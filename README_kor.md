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
[![Downloads](https://img.shields.io/github/downloads/neovim/neovim/total.svg?maxAge=2592000)](https://github.com/neovim/neovim/releases/)

Neovim은 다음에 따라 Vim을 적극적으로 리팩토링하는 프로젝트입니다:

- 유지, 보수를 쉽게 하고 [참여]를 장려합니다.(CONTRIBUTING.md)
- 많은 개발자들과 일을 분담합니다.
- 코어를 수정하지 않고도 [더 나은 UI]를 만들 수 있게 합니다.
- [확장성]을 극대화합니다.(https://github.com/neovim/neovim/wiki/Plugin-UI-architecture)

더 많은 정보를 원하시면 [the wiki](https://github.com/neovim/neovim/wiki/Introduction)와 [Roadmap]를 참고하십시오.

[![Throughput Graph](https://graphs.waffle.io/neovim/neovim/throughput.svg)](https://waffle.io/neovim/neovim/metrics)

소스코드를 통해 설치하기
-------------------

    make CMAKE_BUILD_TYPE=RelWithDebInfo
    sudo make install

'non-default'인 장소에 설치하길 원하시면, `CMAKE_INSTALL_PREFIX`를 선언:

    make CMAKE_EXTRA_FLAGS="-DCMAKE_INSTALL_PREFIX=/full/path/"
    make install

더 많은 정보를 원한다면 [the wiki](https://github.com/neovim/neovim/wiki/Building-Neovim) 참고

패키지를 통해 설치하기
--------------------

Windows, macOS, Linux버전의 미리 구성된 패키지는 다음의 페이지에서 찾을 수 있습니다.
[Releases](https://github.com/neovim/neovim/releases/)

패키지 매니저는 [Homebrew]와 [Debian], [Ubuntu], [Fedora], [Arch Linux], [Gentoo],
, [more](https://github.com/neovim/neovim/wiki/Installing-Neovim)에 있습니다!

프로젝트 구조
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

-  `third-party/`를 비활성화 하려면 `USE_BUNDLED_DEPS=NO`나 `USE_BUNDLED=NO`(CMake option)를 선언하십시오.

특징
--------

- 최신식 [GUIs](https://github.com/neovim/neovim/wiki/Related-projects#gui)
- [API](https://github.com/neovim/neovim/wiki/Related-projects#api-clients)
 - clojure, lisp, go, haskell, lua, javascript, perl, python, ruby, rust 등 모든 언어에서 접근 가능함.
- 내장된, 스크립 가능한 [terminal emulator](https://neovim.io/doc/user/nvim_terminal_emulator.html)
- 비동기식 [job control](https://github.com/neovim/neovim/pull/2247)
- 다수의 편집자를 위한 [Shared data (shada)](https://github.com/neovim/neovim/pull/2506)
- [XDG 기반 디렉토리](https://github.com/neovim/neovim/pull/3470) 지원
- Ruby와 Puthon을 포함한 대부분의 Vim 플러그인과 호환 가능함.

전체 목록을 보고 싶다면 [`:help nvim-features`][nvim-features]를 확인하세요!

라이센스
-------

Neovim은  Vim 라이센스 하에서 기여된 부분을 제외 하고는, Apache 2.0 라이센스를 따르고 있습니다.

- [b17d96][license-commit] 이전에 커밋된 기여는 Vim 라이센스를 따릅니다.

- Contributions committed after [b17d96][license-commit] are licensed under
  Apache 2.0 unless those contributions were copied from Vim (identified in
  the commit logs by the `vim-patch` token).

`LICENSE` 를 확인하십시오.

    Vim 은 "자선웨어(Charityware)"입니다. 원하는 만큼 사용하고 복사할 수 있습니다. 그러나, 
    우간다의 도움이 필요한 아이들을 위해 기부해주실 것을 요청합니다. vim docs의 kcc 섹션을 찾아 보거나
    ICCF 웹사이트를 방문해 보십시오, 다음의 URL을 참고하십시오:

            http://iccf-holland.org/
            http://www.vim.org/iccf/
            http://www.iccf.nl/

    또는, Vim의 개발자에게 후원할 수 도 있습니다. Vim 후원자는 기능 제안을 할 수 있습니다.
    후원금은 우간다로 전해집니다.

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
