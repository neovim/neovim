- **IMPORTANT**: Before upgrading to a new version, **always check for [breaking changes](https://neovim.io/doc/user/news.html#news-breaking).**


## Quick start

1. Install [build prerequisites](#build-prerequisites) on your system
2. `git clone https://github.com/neovim/neovim`
3. `cd neovim`
    - If you want the **stable release**, also run `git checkout stable`.
4. `make CMAKE_BUILD_TYPE=RelWithDebInfo`
    - If you want to install to a custom location, set `CMAKE_INSTALL_PREFIX`. See also [INSTALL.md](./INSTALL.md#install-from-source).
    - On BSD, use `gmake` instead of `make`.
    - To build on Windows, see the [Building on Windows](#building-on-windows) section. _MSVC (Visual Studio) is recommended._
5. `sudo make install`
    - Default install location is `/usr/local`
    - On Debian/Ubuntu, instead of `sudo make install`, you can try `cd build && cpack -G DEB && sudo dpkg -i nvim-linux-<arch>.deb` (with `<arch>` either `x86_64` or `arm64`) to build DEB-package and install it. This helps ensure clean removal of installed files. Note: This is an unsupported, "best-effort" feature of the Nvim build.

**Notes**:
- From the repository's root directory, running `make` will download and build all the needed dependencies and put the `nvim` executable in `build/bin`.
- Third-party dependencies (libuv, LuaJIT, etc.) are downloaded automatically to `.deps/`. See the [FAQ](https://neovim.io/doc/user/faq.html#faq-build) if you have issues.
- After building, you can run the `nvim` executable without installing it by running `VIMRUNTIME=runtime ./build/bin/nvim`.
- If you plan to develop Neovim, install [Ninja](https://ninja-build.org/) for faster builds. It will automatically be used.
- Install [ccache](https://ccache.dev/) for faster rebuilds of Neovim. It's used by default. To disable it, use `CCACHE_DISABLE=true make`.

## Running tests

See [test/README.md](https://github.com/neovim/neovim/blob/master/test/README.md).

## Building

First make sure you installed the [build prerequisites](#build-prerequisites). Now that you have the dependencies, you can try other build targets explained below.

The _build type_ determines the level of used compiler optimizations and debug information:

- `Release`: Full compiler optimizations and no debug information. Expect the best performance from this build type. Often used by package maintainers.
- `Debug`: Full debug information; few optimizations. Use this for development to get meaningful output from debuggers like GDB or LLDB. This is the default if `CMAKE_BUILD_TYPE` is not specified.
- `RelWithDebInfo` ("Release With Debug Info"): Enables many optimizations and adds enough debug info so that when Neovim ever crashes, you can still get a backtrace.

So, for a release build, just use:

```
make CMAKE_BUILD_TYPE=Release
```
(Do not add a `-j` flag if `ninja` is installed! The build will be in parallel automatically.)

Afterwards, the `nvim` executable can be found in `build/bin`. To verify the build type after compilation, run:

```sh
./build/bin/nvim --version | grep ^Build
```

To install the executable to a certain location, use:

```
make CMAKE_INSTALL_PREFIX=$HOME/local/nvim install
```

CMake, our main build system, caches a lot of things in `build/CMakeCache.txt`. If you ever want to change `CMAKE_BUILD_TYPE` or `CMAKE_INSTALL_PREFIX`, run `rm -rf build` first. This is also required when rebuilding after a Git commit adds or removes files (including from `runtime`) — when in doubt, run `make distclean` (which is basically a shortcut for `rm -rf build .deps`).

By default (`USE_BUNDLED=1`), Neovim downloads and statically links its needed dependencies. In order to be able to use a debugger on these libraries, you might want to compile them with debug information as well:

<!-- THIS CAUSES SCREEN INTERFERENCE
```
make distclean
VERBOSE=1 DEBUG=1 make deps
```
-->
```
make distclean
make deps
```

## Building on Windows

### Windows / MSVC

**MSVC (Visual Studio) is the recommended way to build on Windows.** These steps were confirmed as of 2023.

1. Install [Visual Studio](https://visualstudio.microsoft.com/thank-you-downloading-visual-studio/?sku=Community) (2017 or later) with the _Desktop development with C++_ workload.
    - On 32-bit Windows, you will need [this workaround](https://developercommunity.visualstudio.com/content/problem/212989/ninja-binary-format.html).
2. Open the Neovim project folder.
    - Visual Studio should detect the cmake files and automatically start building...
3. Choose the `nvim.exe (bin\nvim.exe)` target and hit F5.
    - If the build fails, it may be because Visual Studio started the build with `x64-{Debug,Release}` before you switched the configuration to `x86-Release`.
      - Right-click _CMakeLists.txt → Delete Cache_.
      - Right-click _CMakeLists.txt → Generate Cache_.
    - If you see an "access violation" from `ntdll`, you can ignore it and continue.
4. If you see an error like `uv.dll not found`, try the `nvim.exe (Install)` target. Then switch back to `nvim.exe (bin\nvim.exe)`.

### Windows / MSVC PowerShell

To build from the command line (i.e. invoke the `cmake` commands yourself),

1. Ensure you have the Visual Studio environment variables, using any of the following:
    - Using the [Visual Studio Developer Command Prompt or Visual Studio Developer PowerShell](https://learn.microsoft.com/en-us/visualstudio/ide/reference/command-prompt-powershell?view=vs-2022)
    - Invoking `Import-VisualStudioVars` in PowerShell from [this PowerShell module](https://github.com/Pscx/Pscx)
    - Invoking `VsDevCmd.bat` in Command Prompt
      ```
      VsDevCmd.bat -arch=x64
      ```
   This is to make sure that `luarocks` finds the Visual Studio installation, and doesn't fall back to MinGW with errors like:
   ```
   'mingw32-gcc' is not recognized as an internal or external command
   ```
2. From the "Developer PowerShell" or "Developer Command Prompt":
   ```
   cmake -S cmake.deps -B .deps -G Ninja -D CMAKE_BUILD_TYPE=Release
   cmake --build .deps --config Release
   cmake -B build -G Ninja -D CMAKE_BUILD_TYPE=Release
   cmake --build build --config Release
   ```
    - Omit `--config Release` if you want a debug build.
    - Omit `-G Ninja` to use the "Visual Studio" generator.

### Windows / CLion

1. Install [CLion](https://www.jetbrains.com/clion/).
2. Open the Neovim project in CLion.
3. Select _Build → Build All in 'Release'_.

### Windows / Cygwin

Since https://github.com/neovim/neovim/pull/36417 , building on Cygwin may be as easy as:

    make && make install

If that fails, an alternative is:

1. Install all dependencies the normal way.
    - The `cygport` repo contains Cygport files (e.g. `APKBUILD`, `PKGBUILD`) for all the dependencies not available in the Cygwin distribution, and describes any special commands or arguments needed to build. The Cygport definitions also try to describe the required dependencies for each one. Unless custom commands are provided, Cygport just calls `autogen`/`cmake`, `make`, `make install`, etc. in a clean and consistent way.
    - https://github.com/cascent/neovim-cygwin was built on Cygwin 2.9.0. Newer `libuv` should require slightly less patching. Some SSP stuff changed in Cygwin 2.10.0, so that might change things too when building Neovim.
2. Build without "bundled" dependencies (except treesitter parsers).
   ```
   cmake -S cmake.deps -B .deps -G Ninja -D CMAKE_BUILD_TYPE=RelWithDebInfo -DUSE_BUNDLED=OFF -DUSE_BUNDLED_TS=ON
   cmake --build .deps
   cmake -B build -G Ninja -D CMAKE_BUILD_TYPE=RelWithDebInfo
   cmake --build build
   ```

### Windows / MSYS2 / MinGW

1. From the MSYS2 shell, install these packages:
   ```
   pacman -S \
       mingw-w64-ucrt-x86_64-gcc \
       mingw-w64-x86_64-{cmake,make,ninja,diffutils}
   ```
2. From the Windows Command Prompt (`cmd.exe`), set up the `PATH` and build.

   ```cmd
   set PATH=c:\msys64\ucrt64\bin;c:\msys64\usr\bin;%PATH%
   ```
3. You have two options:
    - Build using `cmake` and `Ninja` generator:
      ```cmd
      cmake -S cmake.deps -B .deps -G Ninja -D CMAKE_BUILD_TYPE=RelWithDebInfo
      cmake --build .deps
      cmake -B build -G Ninja -D CMAKE_BUILD_TYPE=RelWithDebInfo
      cmake --build build
      ```
      If you cannot install neovim with `ninja install` due to permission restriction, you can install neovim in a directory you have write access to.
      ```cmd
      cmake -S cmake.deps -B .deps -G Ninja -D CMAKE_BUILD_TYPE=RelWithDebInfo
      cmake --build .deps
      cmake -B build -G Ninja -D CMAKE_INSTALL_PREFIX=C:\nvim -D CMAKE_BUILD_TYPE=RelWithDebInfo
      cmake --build build
      ```
    - Or, alternatively, you can use `mingw32-make`:
      ```cmd
      mingw32-make deps
      mingw32-make CMAKE_BUILD_TYPE=RelWithDebInfo
      :: Or you can do the previous command specifying a custom prefix
      :: (Default is C:\Program Files (x86)\nvim)
      :: mingw32-make CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_INSTALL_PREFIX=C:\nvim
      mingw32-make install
      ```

### Windows WSL

Build Ubuntu/Debian linux binary on [WSL](https://learn.microsoft.com/en-us/windows/wsl/install) (Windows Subsystem for Linux).

```bash
# Install build prerequisites
sudo apt-get install ninja-build gettext cmake build-essential

# Build the linux binary in WSL
make CMAKE_BUILD_TYPE=RelWithDebInfo

# Install the linux binary in WSL (with `<arch>` either `x86_64` or `arm64`)
cd build && cpack -G DEB && sudo dpkg -i nvim-linux-<arch>.deb

# Verify the installation
nvim --version && which nvim # should be debug build in /usr/bin/nvim
```

**Note**: If you encounter linker errors or segfaults during the build, Windows libraries in your PATH may be interfering. Use a clean PATH to avoid conflicts:

```bash
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" make CMAKE_BUILD_TYPE=RelWithDebInfo
```

## Localization

### Localization build

Translations are turned off by default. Enable by building Nvim with the CMake flag `ENABLE_TRANSLATIONS=ON`.
Doing this will create `.mo` files in `build/src/nvim/po`. Example:

```
make CMAKE_EXTRA_FLAGS="-DENABLE_TRANSLATIONS=ON"
```

* If you see `msgfmt: command not found`, you need to install [`gettext`](http://en.wikipedia.org/wiki/Gettext). On most systems, the package is just called `gettext`.

### Localization check

To check the translations for `$LANG`, run `make -C build check-po-$LANG`. Examples:

```
cmake --build build --target check-po-de
cmake --build build --target check-po-pt_BR
```

- `check-po-$LANG` generates a detailed report in `./build/src/nvim/po/check-${LANG}.log`. (The report is generated by `nvim`, not by `msgfmt`.)

### Localization update

To update the `src/nvim/po/$LANG.po` file with the latest strings, run the following:

```
cmake --build build --target update-po-$LANG
```

- **Note**: Run `src/nvim/po/cleanup.vim` after updating.

## Compiler options

To see the chain of includes, use the `-H` option ([#918](https://github.com/neovim/neovim/issues/918)):

```sh
echo '#include "./src/nvim/buffer.h"' | \
> clang -I.deps/usr/include -Isrc -std=c99 -P -E -H - 2>&1 >/dev/null | \
> grep -v /usr/
```

- `grep -v /usr/` is used to filter out system header files.
- `-save-temps` can be added as well to see expanded macros or commented assembly.

## Custom Makefile

You can customize the build process locally by creating a `local.mk`, which is referenced at the top of the main `Makefile`. It's listed in `.gitignore`, so it can be used across branches. **A new target in `local.mk` overrides the default make-target.**

Here's a sample `local.mk` which adds a target to force a rebuild but *does not* override the default-target:

```make
all:

rebuild:
	rm -rf build
	make
```

## Third-party dependencies

Reference the [Debian package](https://packages.debian.org/sid/source/neovim) (or alternatively, the [Homebrew formula](https://github.com/Homebrew/homebrew-core/blob/master/Formula/n/neovim.rb)) for the precise list of dependencies/versions.

To build the bundled dependencies using CMake:

```sh
cmake -S cmake.deps -B .deps -G Ninja -D CMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build .deps
```

By default the libraries and headers are placed in `.deps/usr`. Now you can build Neovim:

```sh
cmake -B build -G Ninja -D CMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build build
```

### Build without "bundled" dependencies

1. Manually install the dependencies:
    - libuv libluv libutf8proc luajit lua-lpeg tree-sitter tree-sitter-c tree-sitter-lua tree-sitter-markdown tree-sitter-query tree-sitter-vim tree-sitter-vimdoc unibilium
2. Run CMake:
   ```sh
   cmake -B build -G Ninja -D CMAKE_BUILD_TYPE=RelWithDebInfo
   cmake --build build
   ```
   If all the dependencies are not available in the package, you can use only some of the bundled dependencies as follows (example of using `ninja`):
   ```sh
   cmake -S cmake.deps -B .deps -G Ninja -D CMAKE_BUILD_TYPE=RelWithDebInfo -DUSE_BUNDLED=OFF -DUSE_BUNDLED_TS=ON
   cmake --build .deps
   cmake -B build -G Ninja -D CMAKE_BUILD_TYPE=RelWithDebInfo
   cmake --build build
   ```
3. Run `make`, `ninja`, or whatever build tool you told CMake to generate.
    - Using `ninja` is strongly recommended.
4. If treesitter parsers are not bundled, they need to be available in a `parser/` runtime directory (e.g. `/usr/share/nvim/runtime/parser/`).

### Build offline

On systems with old or missing libraries, *without* network access, you may want
to build *with* bundled dependencies. This is supported as follows.

1. On a network-enabled machine, do either of the following, to get the
   dependency sources in `.deps` in a form that the build will work with:
    - Fetch https://github.com/neovim/deps/tree/master/src into `.deps/build/src/`.
      (https://github.com/neovim/deps/tree/master/src is an auto-updated, "cleaned up", snapshot of `.deps/build/src/`).
    - Run `make deps` to generate `.deps/`, then clean it up using [these commands](https://github.com/neovim/neovim/blob/1c12073db6c64eb365748f153f96be9b0fe61070/.github/workflows/build.yml#L67-L74).
2. Copy the prepared `.deps` to the isolated machine (without network access).
3. Build with `USE_EXISTING_SRC_DIR` enabled, on the isolated machine:
   ```
   make deps DEPS_CMAKE_FLAGS=-DUSE_EXISTING_SRC_DIR=ON
   make
   ```

### Build without unibilium

Unibilium is the only dependency which is licensed under LGPLv3 (there are no
GPLv3-only dependencies). This library is used for loading the terminfo database at
runtime, and can be disabled if the internal definitions for common terminals
are good enough. To avoid this dependency, build with support for loading
custom terminfo at runtime, use

```sh
make CMAKE_EXTRA_FLAGS="-DENABLE_UNIBILIUM=0" DEPS_CMAKE_FLAGS="-DUSE_BUNDLED_UNIBILIUM=0"
```

To confirm at runtime that unibilium was not included, check `has('terminfo') == 1`.

### Build with specific "bundled" dependencies

Example of building with specific bundled and non-bundled dependencies:

```
make DEPS_CMAKE_FLAGS="-DUSE_BUNDLED=OFF -DUSE_BUNDLED_LUV=ON -DUSE_BUNDLED_TS=ON -DUSE_BUNDLED_LIBUV=ON"
```

### Build static binary (Linux)

1. Use a linux distribution which uses musl C. We will use Alpine Linux but any distro with musl should work. (glibc does not support static linking)
2. Run make passing the `STATIC_BUILD` variable: `make CMAKE_EXTRA_FLAGS="-DSTATIC_BUILD=1"`

In case you are not using Alpine Linux you can use a container to do the build the binary:

```sh
podman run \
  --rm \
  -it \
  -v "$PWD:/workdir" \
  -w /workdir \
  alpine:latest \
  sh -c 'apk add build-base cmake coreutils curl gettext-tiny-dev git && make CMAKE_EXTRA_FLAGS="-DSTATIC_BUILD=1"'
```

The resulting binary in `build/bin/nvim` will have all the dependencies statically linked:

```
build/bin/nvim: ELF 64-bit LSB executable, ARM aarch64, version 1 (SYSV), statically linked, BuildID[sha1]=b93fa8e678d508ac0a76a2e3da20b119105f1b2d, with debug_info, not stripped
```

## Build prerequisites

General requirements (see [#1469](https://github.com/neovim/neovim/issues/1469#issuecomment-63058312)):

- Clang or GCC version 4.9+
- CMake version 3.16+, built with TLS/SSL support
  - Optional: Get the latest CMake from https://cmake.org/download/
    - Provides a shell script which works on most Linux systems. After running it, ensure the resulting `cmake` binary is in your $PATH so the the Nvim build will find it.

Platform-specific requirements are listed below.

### Ubuntu / Debian

```sh
sudo apt-get install ninja-build gettext cmake curl build-essential git
```

### RHEL / Fedora

```
sudo dnf -y install ninja-build cmake gcc make gettext curl glibc-gconv-extra git
```

### openSUSE

```
sudo zypper install ninja cmake gcc-c++ gettext-tools curl git
```

### Arch Linux

```
sudo pacman -S base-devel cmake ninja curl git
```

### Alpine Linux

```
apk add build-base cmake coreutils curl gettext-tiny-dev git
```

### Void Linux

```
xbps-install base-devel cmake curl git
```

### NixOS / Nix

Starting from NixOS 18.03, the Neovim binary resides in the `neovim-unwrapped` Nix package (the `neovim` package being just a wrapper to setup runtime options like Ruby/Python support):

```sh
cd path/to/neovim/src
```

Drop into `nix-shell` to pull in the Neovim dependencies:

```
nix-shell '<nixpkgs>' -A neovim-unwrapped
```

Configure and build:

```sh
rm -rf build && cmakeConfigurePhase
buildPhase
```

Tests are not available by default, because of some unfixed failures. You can enable them via adding this package in your overlay:
```
  neovim-dev = (super.pkgs.neovim-unwrapped.override  {
    doCheck=true;
  }).overrideAttrs(oa:{
    cmakeBuildType="debug";

    nativeBuildInputs = oa.nativeBuildInputs ++ [ self.pkgs.valgrind ];
    shellHook = ''
      export NVIM_PYTHON_LOG_LEVEL=DEBUG
      export NVIM_LOG_FILE=/tmp/log
      export VALGRIND_LOG="$PWD/valgrind.log"
    '';
  });
```
and replacing `neovim-unwrapped` with `neovim-dev`:
```
nix-shell '<nixpkgs>' -A neovim-dev
```

A flake for Neovim is hosted at [nix-community/neovim-nightly-overlay](https://github.com/nix-community/neovim-nightly-overlay/), with 3 packages:
- `neovim` to run the nightly
- `neovim-debug` to run the package with debug symbols
- `neovim-developer` to get all the tools to develop on `neovim`

Thus you can run Neovim nightly with `nix run github:nix-community/neovim-nightly-overlay`.
Similarly to develop on Neovim: `nix run github:nix-community/neovim-nightly-overlay#neovim-developer`.

To use a specific version of Neovim, you can pass `--override-input neovim-src .` to use your current directory,
or a specific SHA1 like `--override-input neovim-src github:neovim/neovim/89dc8f8f4e754e70cbe1624f030fb61bded41bc2`.

### Haiku

Some deps can be pulled from haiku repos, the rest need "bundled" deps:

    cmake -DUSE_BUNDLED_LIBUV=OFF -DUSE_BUNDLED_UNIBILIUM=OFF -DUSE_BUNDLED_LUAJIT=OFF -B .deps ./cmake.deps
    make -C .deps

### FreeBSD

```
sudo pkg install cmake gmake sha wget gettext curl git
```

If you get an error regarding a `sha256sum` mismatch, where the actual SHA-256 hash is `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`, then this is your issue (that's the `sha256sum` of an empty file).

### OpenBSD

```sh
doas pkg_add gmake cmake curl gettext-tools git ninja
```

While `ninja` is technically optional, the build is likely to fail without it. This is because `cmake` will use `make` in that case, and the bundled LuaJIT requires `gmake`. Instead of installing `ninja`, you could work around this by installing `luajit` and disabling the bundled LuaJIT:

```sh
gmake DEPS_CMAKE_FLAGS="-DUSE_BUNDLED_LUAJIT=0"
```

Another workaround is to edit `cmake/Deps.cmake` and comment out the line `set(MAKE_PRG "$(MAKE)")`. This will leave `MAKE_PRG` set to `gmake`, so LuaJIT will be built with `gmake`.

### macOS

#### macOS / Homebrew

1. Install Xcode Command Line Tools: `xcode-select --install`
2. Install [Homebrew](http://brew.sh)
3. Install Neovim build dependencies:
    ```
    brew install ninja cmake gettext curl git
    ```
  - **Note**: If you see Wget certificate errors (for older macOS versions less than 10.10):
    ```sh
    brew install curl-ca-bundle
    echo CA_CERTIFICATE=$(brew --prefix curl-ca-bundle)/share/ca-bundle.crt >> ~/.wgetrc
    ```
  - **Note**: If you see `'stdio.h' file not found`, try the following:
    ```
    open /Library/Developer/CommandLineTools/Packages/macOS_SDK_headers_for_macOS_10.14.pkg
    ```

#### macOS / MacPorts

1. Install Xcode Command Line Tools: `xcode-select --install`
2. Install [MacPorts](http://www.macports.org)
3. Install Neovim build dependencies:
    ```
    sudo port install ninja cmake gettext git
    ```
  - **Note**: If you see Wget certificate errors (for older macOS versions less than 10.10):
    ```sh
    sudo port install curl-ca-bundle
    echo CA_CERTIFICATE=/opt/local/share/curl/curl-ca-bundle.crt >> ~/.wgetrc
    ```
  - **Note**: If you see `'stdio.h' file not found`, try the following:
    ```
    open /Library/Developer/CommandLineTools/Packages/macOS_SDK_headers_for_macOS_10.14.pkg
    ```

#### Building for older macOS versions

From a newer macOS version, to build for older macOS versions, you will have to set the macOS deployment target:

```
make CMAKE_BUILD_TYPE=Release MACOSX_DEPLOYMENT_TARGET=10.13 DEPS_CMAKE_FLAGS="-DCMAKE_CXX_COMPILER=$(xcrun -find c++)"
```

Note that the C++ compiler is explicitly set so that it can be found when the deployment target is set.

## Building with zig
### Prerequisites
 - zig 0.15.2
### Instructions
 - Build the editor: `zig build`, run it with `./zig-out/bin/nvim`
 - Complete installation with runtime: `zig build install --prefix ~/.local`
 - Tests:
   + `zig build functionaltest` to run all functionaltests
   + `zig build functionaltest -- test/functional/autocmd/bufenter_spec.lua` to run the tests in one file
   + `zig build unittest` to run all unittests
#### Using system dependencies
  See "Available System Integrations" in `zig build -h` to see available system integrations. Enabling an integration, e.g. `zig build -fsys=utf8proc` will use the system's installation of utf8proc.

`zig build --system deps_dir` will enable all integrations and turn off dependency fetching. This requires you to pre-download the dependencies which don't have a system integration into `deps_dir` (at the time of writing these are ziglua, [`lua_dev_deps`](https://github.com/neovim/deps/blob/master/opt/lua-dev-deps.tar.gz), and the built-in tree-sitter parsers). You have to create subdirectories whose names are the respective package's hash under `deps_dir` and unpack the dependencies inside that directory - ziglua should go under `deps_dir/zlua-0.1.0-hGRpC1dCBQDf-IqqUifYvyr8B9-4FlYXqY8cl7HIetrC` and so on. Hashes should be taken from `build.zig.zon`.

See the `prepare` function of [this `PKGBUILD`](https://git.sr.ht/~chinmay/nvim_build/tree/26364a4cf9b4819f52a3e785fa5a43285fb9cea2/item/PKGBUILD#L90) for an example.
