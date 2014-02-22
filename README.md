# neovim ([bountysource fundraiser](https://www.bountysource.com/fundraisers/539-neovim-first-iteration))

### Introduction

Vim is a powerful text editor with a big community that is constantly growing.  Even though the editor is about two decades old, people still extend and want to improve it, mostly using vimscript or one of the supported scripting languages.

### Problem

Over its more than 20 years of life, vim has accumulated about 300k lines of scary C89 code that very few people understand or have the guts to mess with.

Another issue, is that as the only person responsible for maintaining vim's big codebase, Bram Moolenaar has to be extra-careful before accepting patches, because once merged, the new code will be his responsibility.

These problems make it very difficult to have new features and bug fixes merged into the core. Vim just can't keep up with the development speed of its plugin ecosystem.

### Solution

Neovim is a project that seeks to aggressively refactor vim source code in order to achieve the following goals:

- Simplify maintenance to improve the speed that bug fixes and features get merged.
- Split the work between multiple developers.
- Enable the implementation of new/modern user interfaces without any modifications to the core source.
- Improve the extensibility power with a new plugin architecture based on coprocesses. Plugins will be written in any programming language without any explicit support from the editor.

By achieving those goals new developers will soon join the community, consequently improving the editor for all users.

It is important to emphasize that this is not a project to rewrite vim from scratch or transform it into an IDE (though the new features provided will enable IDE-like distributions of the editor). The changes implemented here should have little impact on vim's editing model or vimscript in general. Most vimscript plugins should continue to work normally.

The following topics contain brief explanations of the major changes (and motivations) that will be performed in the first iteration:

* <a href="#build"><b>Migrate to a cmake-based build</b></a>
* <a href="#legacy"><b>Legacy support and compile-time features</b></a>
* <a href="#platform"><b>Platform-specific code</b></a>
* <a href="#plugins"><b>New plugin architecture</b></a>
* <a href="#gui"><b>New GUI architecture</b></a>
* <a href="#development"><b>Development on github</b></a>

<a name="build"></a>
##### Migrate to a cmake-based build

The source tree has dozens (if not hundreds) of files dedicated to building vim with on various platforms with different configurations, and many of these files look abandoned or outdated. Most users don't care about selecting individual features and just compile using '--with-features=huge', which still generates an executable that is small enough even for lightweight systems by today's standards.

All those files will be removed and vim will be built using [cmake](http://www.cmake.org), a modern build system that generates build scripts for the most relevant platforms.

<a name="legacy"></a>
##### Legacy support and compile-time features

Vim has a significant amount of code dedicated to supporting legacy systems and compilers. All that code increases the maintenance burden and will be removed.

Most optional features will no longer be optional (see above), with the exception of some broken and useless features (eg: netbeans integration, sun workshop) which will be removed permanently. Vi emulation will also be removed (setting 'nocompatible' will be a no-op).

These changes wont affect most users. Those that only have a C89 compiler installed or use vim on legacy systems such as Amiga, BeOS or MSDOS will have two options:

- Upgrade their software
- Continue using vim

<a name="platform"></a>
##### Platform-specific code

Most of the platform-specific code will be removed and [libuv](https://github.com/joyent/libuv) will be used to handle system differences.

libuv is a modern multi-platform library with functions to perform common system tasks, and supports most unixes and windows, so the vast majority of vim's community will be covered.

<a name="plugins"></a>
##### New plugin architecture

All code supporting embedded scripting language interpreters will be replaced by a new plugin system that will support extensions written in any programming language.

Compatibility layers will be provided for vim plugins written in some of the currently supported scripting languages such as python or ruby. Most plugins should work on neovim with little modifications, if any.

This is how the new plugin system will work:

- Plugins are long-running programs/jobs (coprocesses) that communicate with vim through stdin/stdout using msgpack-rpc or json-rpc.
- Vim will discover and run these programs at startup, keeping two-way communication channels with each plugin through its lifetime.
- Plugins will be able to listen to events and send commands to vim asynchronously.

This system will be built on top of a job control mechanism similar to the one implemented by the [job control patch](https://groups.google.com/forum/#!topic/vim_dev/QF7Bzh1YABU)

Here's an idea of how a plugin session might work using [json-rpc](http://www.jsonrpc.org/specification) (jsonrpc version omitted):

```js
plugin -> neovim: {"id": 1, "method": "listenEvent", "params": {"eventName": "keyPressed"}}
neovim -> plugin: {"id": 1, "result": true}
neovim -> plugin: {"method": "event", "params": {"name": "keyPressed", "eventArgs": {"keys": ["C"]}}}
neovim -> plugin: {"method": "event", "params": {"name": "keyPressed", "eventArgs": {"keys": ["Ctrl", "Space"]}}}
plugin -> neovim: {"id": 2, "method": "showPopup", "params": {"size": {"width": 10, "height": 2} "position": {"column": 2, "line": 3}, "items": ["Completion1", "Completion2"]}}
plugin -> neovim: {"id": 2, "result": true}}
```

That shows an hypothetical conversation between neovim and completion plugin that displays completions when the user presses Ctrl+Space. The above scheme gives neovim near limitless extensibility and also improves stability as plugins will automatically be isolated from the main executable.

This system can also easily emulate the current scripting languages interfaces to vim. For example, a plugin can emulate the python interface by running python scripts sent by vim in its own context and by exposing a 'vim' module with an API matching the current one. Calls to the API would simply be translated to json-rpc messages sent to vim.


<a name="gui"></a>
##### New GUI architecture

Another contributing factor to vim's huge codebase is the explicit support for dozens of widget toolkits for GUI interfaces. Like the legacy code support, gui-specific code will be removed.

Neovim will handle GUIs similarly to how it will handle plugins:

- GUIs are separate programs, possibly written in different programming languages.
- Neovim will use its own stdin/stdout to receive input and send updates, again using json-rpc or msgpack-rpc.

The difference between plugins and GUIs is that plugins will be started by neovim, where neovim will be started by programs running the GUI. Here's a sample diagram of the process tree:

```
GUI program
  |
  ---> Neovim
         |
         ---> Plugin 1
         |
         ---> Plugin 2
         |
         ---> Plugin 3
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

- Modern GUIs written in high-level programming languages that integrate better with the operating system. We can have GUIs written using C#/WPF on Windows or Ruby/Cocoa on Mac, for example.
- Plugins will be able to emit custom events that may be handled directly by GUIs.  This will enable the implementation of advanced features such as sublime's minimap.
- A multiplexing daemon could keep neovim instances running in a headless server, while multiple remote GUIs could attach/detach to share editing sessions.
- Simplified headless testing.
- Embedding the editor into other programs. In fact, a GUI can be seen as a program that embeds neovim.

Here's a diagram that illustrates how a client-server process tree might look like:

```
Server daemon listening on tcp sockets <------ GUI 1 (attach/detach to running instances using tcp sockets)
  |                                       |
  ---> Neovim                             |
         |                                GUI 2 (sharing the same session with GUI 1)
         ---> Plugin 1
         |
         ---> Plugin 2
         |
         ---> Plugin 3
```


<a name="development"></a>
##### Development on Github

Development will happen on the [github organization](https://github.com/neovim), and the code will be split across many repositories, unlike the current vim source tree.

There will be separate repositories for GUIs, plugins, runtime files (official vimscript) and distributions. This will let the editor receive improvements much faster as the patches don't have to go all through a single person for approval.

Travis will also be used for continuous integration, so pull requests will be automatically checked.

### Status

Here's a list of things that have been done so far:

- Source tree was cleaned up, leaving only files necessary for compilation/testing of the core.
- Source files were processed with [unifdef](http://freecode.com/projects/unifdef) to remove tons of FEAT_* macros
- Files were processed with [uncrustify](http://uncrustify.sourceforge.net/) to normalize source code formatting.
- The autotools build system was replaced by [cmake](http://www.cmake.org/)

and what is currently being worked on:

- Port all IO to libuv

###Dependencies

For Ubuntu 12.04:

    sudo apt-get install build-essential cmake libncurses5-dev

For OsX:

* Install [Xcode](https://developer.apple.com/)
* Install sha1sum

  Via MacPorts:

      sudo port install md5sha1sum cmake libtool

  Via Homebrew:

      brew install md5sha1sum cmake libtool

For Arch Linux:

      sudo pacman -S base-devel cmake ncurses

TODO: release the Dockerfile which has this in it



###Building

To generate the `Makefile`s:

    make cmake

To build and run the tests:

    make test

### Community

Join the community on IRC in #neovim on Freenode.

### Contributing

...would be awesome! See [the wiki](https://github.com/neovim/neovim/wiki/Contributing) for more details.

### License

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

