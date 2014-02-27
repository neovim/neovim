# Installation instructions

Neovim has very few external dependencies which *must* be installed. It ships
with uncommon dependencies bundled into the ``third-party`` directories. These
are used for the "simple" compilation method outlined below.

Those dependencies which must be installed are:

* A working compiler, usually GCC
* CMake
* Autotools

Those dependencies which *may* be installed are:

* [libuv](https://github.com/joyent/libuv).

## Building neovim

There are many ways to build neovim depending on your needs and the amount of
customization you require.

### The all-in-one build script

This method makes use of the dependencies bundled with the source tree and is
provided as a convenience to those whose platforms do not provide packages for
the dependencies and who do not wish to install them separately. Compilation is
via a Makefile in the ``scripts/`` directory. In the top-level directory simply:

```console
$ make -C scripts/ build
```

To run the tests:
```console
$ make -C scripts/ test
```

There is also a top-level Makefile which will forward ``build`` and ``test`` to
the ``scripts/Makefile``. This is purely for compatibility with some existing
build scripts and will be removed.

### CMake

If you are packaging neovim or if you already have all the dependencies
installed on your system, a standard CMake-based build may be used. This is the
recommended option for developers since it will rapidly show any regressions
between updated dependencies and neovim.

```console
$ mkdir build && cd build
$ cmake .. && make              # For normal 'make'-based builds.
$ cmake -G Ninja .. && ninja    # For faster builds using the 'ninja' utility.
```

### Homebrew on Mac

    brew install neovim/neovim/neovim


## Installing Dependencies

This section gives some advice about installing the dependencies on various
platforms.

<a name="for-debianubuntu"></a>
### Ubuntu/Debian

    sudo apt-get install libtool autoconf automake cmake libncurses5-dev g++

Versions of Ubuntu prior to trusty (14.04) do not provide a libuv package. You
may either compile it from source or use the "simple" build method above.

<a name="for-centos-rhel"></a>
### CentOS/RHEL

If you're using CentOS/RHEL 6 you need at least autoconf version 2.69 for
compiling the libuv dependency. See joyent/libuv#1158.

<a name="for-freebsd-10"></a>
### FreeBSD 10

    sudo pkg install cmake libtool sha

<a name="for-arch-linux"></a>
### Arch Linux

    sudo pacman -S base-devel cmake ncurses

<a name="for-os-x"></a>
### OS X

* Install [Xcode](https://developer.apple.com/) and [Homebrew](http://brew.sh)
  or [MacPorts](http://www.macports.org)
* Install sha1sum

If you run into wget certificate errors, you may be missing the root SSL
certificates or have not set them up correctly:

  Via MacPorts:

      sudo port install curl-ca-bundle libtool automake cmake
      echo CA_CERTIFICATE=/opt/local/share/curl/curl-ca-bundle.crt >> ~/.wgetrc

  Via Homebrew:

      brew install curl-ca-bundle libtool automake cmake
      echo CA_CERTIFICATE=$(brew --prefix curl-ca-bundle)/share/ca-bundle.crt >> ~/.wgetrc

