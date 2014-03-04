# neovim ([bountysource fundraiser](https://www.bountysource.com/fundraisers/539-neovim-first-iteration))

[![Build Status](https://travis-ci.org/neovim/neovim.png?branch=master)](https://travis-ci.org/neovim/neovim)
[![Stories in Ready](https://badge.waffle.io/neovim/neovim.png?label=ready)](https://waffle.io/neovim/neovim)

* [Introduction](#introduction)
* [Problem](#problem)
* [Solution](#solution)
  * [Migrate to a cmake-based build](#migrate-to-a-cmake-based-build)
  * [Legacy support and compile-time features](#legacy-support-and-compile-time-features)
  * [Platform-specific code](#platform-specific-code)
  * [New plugin architecture](#new-plugin-architecture)
  * [New GUI architecture](#new-gui-architecture)
  * [Development on github](#development-on-github)
* [Status](#status)
* [Dependencies](#dependencies)
  * [For Debian/Ubuntu](#for-debianubuntu)
  * [For CentOS/RHEL](#for-centos-rhel)
  * [For FreeBSD 10](#for-freebsd-10)
  * [For Arch Linux](#for-arch-linux)
  * [For OS X](#for-os-x)
* [Building](#building)
* [Community](#community)
* [Contributing](#contributing)
* [License](#license)

## Introduction

Vim is a powerful text editor with a big community that is constantly
growing.  Even though the editor is about two decades old, people still extend
and want to improve it, mostly using vimscript or one of the supported scripting
languages.

## Problem

Over its more than 20 years of life, vim has accumulated about 300k lines of
scary C89 code that very few people understand or have the guts to mess with.

Another issue is that as the only person responsible for maintaining vim's big
codebase, Bram Moolenaar has to be extra careful before accepting patches,
because once merged, the new code will be his responsibility.

These problems make it very difficult to have new features and bug fixes merged
into the core. Vim just can't keep up with the development speed of its plugin
ecosystem.

## Solution

Neovim is a project that seeks to aggressively refactor vim source code in order
to achieve the following goals:

- Simplify maintenance to improve the speed that bug fixes and features get
  merged.
- Split the work between multiple developers.
- Enable the implementation of new/modern user interfaces without any
  modifications to the core source.
- Improve the extensibility power with a new plugin architecture based on
  coprocesses. Plugins will be written in any programming language without
  any explicit support from the editor.

By achieving those goals new developers will soon join the community,
consequently improving the editor for all users.

It is important to emphasize that this is not a project to rewrite vim from
scratch or transform it into an IDE (though the new features provided will
enable IDE-like distributions of the editor). The changes implemented here
should have little impact on vim's editing model or vimscript in general. Most
vimscript plugins should continue to work normally.

The following topics contain brief explanations of the major changes (and
motivations) that will be performed in the first iteration:

* [Migrate to a CMake-based build](#build)
* [Legacy support and compile-time features](#legacy)
* [Platform-specific code](#platform)
* [New plugin architecture](#plugins)
* [New GUI architecture](#gui)
* [Development on GitHub](#development)

<a name="build"></a>
### Migrate to a CMake-based build

The source tree has dozens (if not hundreds) of files dedicated to building vim
with on various platforms with different configurations, and many of these files
look abandoned or outdated. Most users don't care about selecting individual
features and just compile using `--with-features=huge`, which still generates an
executable that is small enough even for lightweight systems by today's
standards.

All those files will be removed and vim will be built using [CMake][], a modern
build system that generates build scripts for the most relevant platforms.

[CMake]: http://cmake.org/

<a name="legacy"></a>
### Legacy support and compile-time features

Vim has a significant amount of code dedicated to supporting legacy systems and
compilers. All that code increases the maintenance burden and will be removed.

Most optional features will no longer be optional (see above), with the
exception of some broken and useless features (e.g.: NetBeans and Sun WorkShop
integration) which will be removed permanently. Vi emulation will also be
removed (setting `nocompatible` will be a no-op).

These changes won't affect most users. Those that only have a C89 compiler
installed or use vim on legacy systems such as Amiga, BeOS or MS-DOS will
have two options:

- Upgrade their software
- Continue using vim

<a name="platform"></a>
### Platform-specific code

Most of the platform-specific code will be removed and [libuv][] will be used to
handle system differences.

libuv is a modern multi-platform library with functions to perform common system
tasks, and supports most unixes and windows, so the vast majority of vim's
community will be covered.

[libuv]: https://github.com/joyent/libuv

<a name="plugins"></a>
### New plugin architecture

All code supporting embedded scripting language interpreters will be replaced by
a new plugin system that will support extensions written in any programming
language.

Compatibility layers will be provided for vim plugins written in some of the
currently supported scripting languages such as Python or Ruby. Most plugins
should work on neovim with little modifications, if any.

This is how the new plugin system will work:

- Plugins are long-running programs/jobs (coprocesses) that communicate with vim
  through stdin/stdout using msgpack-rpc or json-rpc.
- Vim will discover and run these programs at startup, keeping two-way
  communication channels with each plugin through its lifetime.
- Plugins will be able to listen to events and send commands to vim
  asynchronously.

This system will be built on top of a job control mechanism similar to the one
implemented by the [job control patch][].

Here's an idea of how a plugin session might work using [json-rpc][] (json-rpc version omitted):

```js
plugin -> neovim: {"id": 1, "method": "listenEvent", "params": {"eventName": "keyPressed"}}
neovim -> plugin: {"id": 1, "result": true}
neovim -> plugin: {"method": "event", "params": {"name": "keyPressed", "eventArgs": {"keys": ["C"]}}}
neovim -> plugin: {"method": "event", "params": {"name": "keyPressed", "eventArgs": {"keys": ["Ctrl", "Space"]}}}
plugin -> neovim: {"id": 2, "method": "showPopup", "params": {"size": {"width": 10, "height": 2} "position": {"column": 2, "line": 3}, "items": ["Completion1", "Completion2"]}}
plugin -> neovim: {"id": 2, "result": true}}
```

That shows a hypothetical conversation between neovim and a completion plugin
which displays completions when the user presses Ctrl+Space. The above scheme
gives neovim near limitless extensibility and also improves stability as plugins
will be automatically isolated from the main executable.

This system can also easily emulate the current scripting language interfaces
to vim. For example, a plugin can emulate the Python interface by running
Python scripts sent by vim in its own context and by exposing a `vim` module
with an API matching the current one. Calls to the API would simply be
translated to json-rpc messages sent to vim.

[job control patch]: https://groups.google.com/forum/#!topic/vim_dev/QF7Bzh1YABU
[json-rpc]: http://www.jsonrpc.org/specification

<a name="gui"></a>
### New GUI architecture

Another contributing factor to vim's huge codebase is the explicit support for
dozens of widget toolkits for GUI interfaces. Like the legacy code support,
GUI-specific code will be removed.

Neovim will handle GUIs similarly to how it will handle plugins:

- GUIs are separate programs, possibly written in different programming languages.
- Neovim will use its own stdin/stdout to receive input and send updates, again
  using json-rpc or msgpack-rpc.

The difference between plugins and GUIs is that plugins will be started by
neovim, whereas neovim will be started by programs running the GUI. Here's a
sample diagram of the process tree:

```
GUI program
  |
  `--> Neovim
         |
         `--> Plugin 1
         |
         `--> Plugin 2
         |
         `--> Plugin 3
```

Hypothetical GUI session:

```js
gui -> vim: {"id": 1, "method": "initClient", "params": {"size": {"rows": 20, "columns": 25}}}
vim -> gui: {"id": 1, "result": {"clientId": 1}}
vim -> gui: {"method": "redraw", "params": {"clientId": 1, "lines": {"5": "   Welcome to neovim!   "}}}
gui -> vim: {"id": 2, "method": "keyPress", "params": {"keys": ["H", "e", "l", "l", "o"]}}
vim -> gui: {"method": "redraw", "params": {"clientId": 1, "lines": {"1": "Hello                   ", "5": "                        "}}}
```

This new GUI architecture creates many interesting possibilities:

- Modern GUIs written in high-level programming languages that integrate better
  with the operating system. We can have GUIs written using C#/WPF on Windows
  or Ruby/Cocoa on OS X, for example.
- Plugins will be able to emit custom events that may be handled directly by
  GUIs.  This will enable the implementation of advanced features such as
  Sublime's minimap.
- A multiplexing daemon could keep neovim instances running in a headless
  server, while multiple remote GUIs could attach/detach to share editing
  sessions.
- Simplified headless testing.
- Embedding the editor into other programs. In fact, a GUI can be seen as a
  program that embeds neovim.

Here's a diagram that illustrates how a client-server process tree might look like:

```
Server daemon listening on tcp sockets <------ GUI 1 (attach/detach to running instances using tcp sockets)
  |                                       |
  `--> Neovim                             |
         |                                GUI 2 (sharing the same session with GUI 1)
         `--> Plugin 1
         |
         `--> Plugin 2
         |
         `--> Plugin 3
```


<a name="development"></a>
### Development on GitHub

Development will happen in the [GitHub organization][], and the code will be
split across many repositories, unlike the current vim source tree.

There will be separate repositories for GUIs, plugins, runtime files (official
vimscript) and distributions. This will let the editor receive improvements much
faster, as the patches don't have to go all through a single person for approval.

Travis will also be used for continuous integration, so pull requests will be
automatically checked.

[GitHub organization]: https://github.com/neovim

## Status

Here's a list of things that have been done so far:

- Source tree was cleaned up, leaving only files necessary for compilation/testing of the core.
- Source files were processed with [unifdef][] to remove tons of `FEAT_*` macros.
- Files were processed with [uncrustify][] to normalize source code formatting.
- The autotools build system was replaced by [CMake][].

and what is currently being worked on:

- Porting all IO to libuv.

[unifdef]: http://freecode.com/projects/unifdef
[uncrustify]: http://uncrustify.sourceforge.net/
[CMake]: http://cmake.org/

## Dependencies

<a name="for-debianubuntu"></a>
### Ubuntu/Debian

    sudo apt-get install libtool autoconf automake cmake libncurses5-dev g++

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
* Install libtool, automake and cmake:

  Via MacPorts:

      sudo port install libtool automake cmake
      
  Via Homebrew:

      brew install libtool automake cmake

If you run into wget certificate errors, you may be missing the root SSL
certificates or have not set them up correctly:

  Via MacPorts:

      sudo port install curl-ca-bundle
      echo CA_CERTIFICATE=/opt/local/share/curl/curl-ca-bundle.crt >> ~/.wgetrc

  Via Homebrew:

      brew install curl-ca-bundle
      echo CA_CERTIFICATE=$(brew --prefix curl-ca-bundle)/share/ca-bundle.crt >> ~/.wgetrc


## Building

To generate the `Makefile`s:

    make cmake

To build and run the tests:

    make test

Using Homebrew on Mac:

    brew install --HEAD https://raw.github.com/neovim/neovim/master/neovim.rb

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
