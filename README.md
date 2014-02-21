#neovim

###Introduction

Vim is a powerful text editor with a big community that is constantly growing.
Even though the editor is over two decades old, people still extend and improve
it, mostly using vimscript or one of the supported scripting languages.

###Problem

Over its more than 20 years of life, vim has accumulated about 300k lines of
scary C89 code that very few people understand or have the guts to mess with.

Another issue, is that as the only person responsible for maintaing vim's big
codebase, Bram Moolenaar has to be extra-careful before accepting patches,
because once merged, the new code will be his responsibility.

These problems make it very difficult to have new features and bug fixes merged
into the core. Vim just cant keep up with the development speed of its plugin
echosystem.

###Solution

Neovim is a vim fork that seeks to aggressively refactor vim in order to achieve
the following goals:

- Simplify maintenance to improve the speed that bug fixes and
  features get merged.
- Split the maintainance work between multiple developers.
- Enable the implementation of new/modern user interfaces without any modifications
  to the core source. 
- Improve the extensibility power with a new plugin architecture based on
  external processes. Plugins will be written in any programming language
  without any explicit support from the editor.

A consequence of achieving those goals is that new developers will join the
community, consequently improving the editor for all users.

It is important to empathise that this is not a project to rewrite vim from the
scratch or transform it into an IDE(though the new features provided will make
it possible to build IDE-like distributions of the editor). The changes
implemented here should have little impact on vim's editing model or vimscript
in general. Most vimscript plugins should continue to work normally.

Each of the following topics will briefly explain the major changes that will
be performed in the first iterations:

* <a href="#build"><b>Migrate to a cmake-based build</b></a>
* <a href="#legacy"><b>Legacy support and compile-time features</b></a>
* <a href="#platform"><b>Platform-specific code </b></a>
* <a href="#plugins"><b>New plugin architecture</b></a>
* <a href="#gui"><b>New GUI architecture</b></a>
* <a href="#split"><b>Split into many repositories</b></a>

<a name="build"></a>
##### Migrate to a cmake-based build

The source tree has dozens(if not hundreds) of files dedicated to building vim
with on various platforms with different configurations, and many of these files
look abandoned or outdated. Most users dont care about selecting individual
features and just compile using '--with-features=huge', which still generates an
executable that is small enough even for lightweight systems(by today's
standards).

All those files will be removed and vim will be built using
[cmake](www.cmake.org), a modern build system that generates build scripts for
the most relevant platforms.

<a name="legacy"></a>
##### Legacy support and compile-time features

Vim has a significant amount of code dedicated to supporting legacy systems and
compilers. All that code increases the maintainance burden and will be removed.

Most optional features will no longer be optional(see above), with the exception
of some broken and useless fetures(eg: netbeans integration, sun workshop) which
will be removed permanently. Vi emulation will also be removed(probably leave
the 'set nocompatible' command as a no-op).

These changes wont affect most users. Those that only have a C89 compiler
installed or use vim on legacy systems such as Amiga, BeOS or MSDOS have two
options:

- Upgrade their software
- Continue using vim

<a name="platform"></a>
##### Platform-specific code

Most of the platform-specific code will be removed and
[libuv](https://github.com/joyent/libuv) will be used to handle system
differences.

libuv is a modern multi-platform library with functions to perform
common system tasks, and supports most unixes and windows, so the vast majority
of vim's community will be covered.

<a name="plugins"></a>
##### New plugin architecture

All code supporting embedded scripting language interpreters will be replaced
by a new plugin system that will support extensions written in any programming
language.

Compatibility layers will be provided for vim plugins written in some of the
currently supported scripting languages such as python or ruby. Most plugins
should work on neovim with little modifications, if any.

This is how the new plugin system will work:

- Plugins are long-running programs/jobs that communicate with vim through
  stdin/stdout using msgpack-rpc or json-rpc.
- Vim will discover and run these programs at startup, keeping two-way communication
  channels with each plugin.
- Plugins will be able to listen to events and send commands to vim
  asynchronously.

This system will be built on top of a job control mechanism similar to the one
provided by the [job control patch](https://groups.google.com/forum/#!topic/vim_dev/QF7Bzh1YABU)

Here's an idea of how a plugin session will work using [json-rpc](http://www.jsonrpc.org/specification) (jsonrpc version omitted):

```js
plugin -> neovim: {"id": 1, "method": "listenEvent", "params": {"eventName": "keyPressed"}}
neovim -> plugin: {"id": 1, "result": true}
neovim -> plugin: {"method": "event", "params": {"name": "keyPressed", "eventArgs": {"keys": ["C"]}}}
neovim -> plugin: {"method": "event", "params": {"name": "keyPressed", "eventArgs": {"keys": ["Ctrl", "Space"]}}}
plugin -> neovim: {"id": 2, "method": "showPopup", "params": {"size": {"width": 10, "height": 2} "position": {"column": 2, "line": 3}, "items": ["Completion1", "Completion2"]}}
plugin -> neovim: {"id": 2, "result": true}}
```

That shows an hypothetical conversation between neovim and completion plugin
that displays completions when the user presses Ctrl+Space. The above scheme
gives neovim near limitless extensibility and also improves stability as plugins
will automatically be isolated from the main executable. 

This system can also easily emulate the current scripting languages interfaces
to vim. For example, a plugin can emulate the python interface by running python
scripts sent by vim in its own context and by exposing a 'vim' module with an
API matching the current one. Calls to the API would simply be translated to
json-rpc messages sent to vim.


<a name="gui"></a>
##### New GUI architecture

Another contributing factor to vim's huge codebase is the explicit support for
dozens of widget toolkits for GUI interfaces. Like the legacy code support, gui
handling code will be removed from the core.

Neovim will handle GUIs similarly to how it will handle plugins:

- GUIs are separate programs, possibly written in different programming
  languages.
- Neovim will use its own stdin/stdout to receive input and send updates, again
  using json-rpc or msgpack-rpc.

The difference between plugins and GUIs is that plugins will be started by
neovim, where neovim will be started by programs running the GUI. Here's a sample
diagram of the process tree:

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

- Modern GUIs written in high-level programming languages that integrate better
  with the operating system. We can have GUIs written using C#/WPF on
  Windows or Ruby/Cocoa on Mac, for example.
- Plugins will be able emit custom events that may be handled directly by GUIs.
  This will enable the implementaton of advanced features such as sublime's
  minimap. 
- A multiplexing daemon could keep neovim instances running in a headless
  server, while multiple remote GUIs could attach/detach to share editing
  sessions.
- Simplified headless testing.
- Embedding the editor into other programs.

Here's a diagram that illustrates how a client-server process tree might look
like:

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
##### Development

Development will happen on the [neovim organization](https://github.com/neovim),
and the code will be split across many repositories. There will be separate
repositories for GUIs, plugins, runtime files(official vimscript) and
distributions. This will let the editor receive improvements much faster as the
patches dont have to go all through a single person for approval.

Travis will also be used for continuous integration, so pull requests will be
automatically checked.

###Future

The changes described are relatively simple to integrate and will be part of the
first iteration. Here are more possibilities for the future:

- Refactor the way input is read. Heres a great simplification of how vim
  currently works: `while (true) { process_input(getc()); }`, we want to remove
  the `while(true)` chunks from the core and provide something like this:
  `process_input(char c)`. This will help extract the editor logic into a
  library.
- Remove all globals. Basically every function will receive a pointer to a
  struct representing the editor and containing data currently held by global
  variables. Helpful if a 'libvim' is implemented in the future.
- Replace the current vimscript C implementation by [lua](www.lua.org)
  or [luajit](www.luajit.org) and compile vimscript into lua, similarly to how
  coffeescript is compiled into javascript. This will greatly reduce the
  maintainance burden and give vimscript a real boost in performance.
  

###Status

Here's a list of things that have been done so far:

- Source tree was cleaned up, leaving only files necessary for
  compilation/testing of the core.
- Source files were processed with
  [unifdef](http://freecode.com/projects/unifdef) to remove tons of FEAT_*
  macros
- Files were processed with [uncrustify](http://uncrustify.sourceforge.net/) to
  normalize source code formatting.
- The autotools build system was replaced by [cmake](http://www.cmake.org/)

and of what is being currently worked on:

- Port all IO to libuv

###Dependencies

For Ubuntu 12.04:

    sudo apt-get install build-essential cmake libncurses5-dev

TODO: release the Dockerfile which has this in it

TODO: Arch instructions

TODO: OSX instructions


###Building

To generate the `Makefile`s:

    make cmake

To build and run the tests:

    make test


