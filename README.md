#neovim

###Introduction

Vim is a powerful text editor with a big, increasing community. Even though it
is more than 20 years old, people still extend and improve it, mostly using
vimscript or one of the supported scripting languages.

###Problem

Over its 20 years of life, vim has accumulated about 300k lines of scary C89
code that very few people understand or have the guts to mess with.

Another issue, is that as the only person responsible for maintaing vim's big
codebase, Bram Moolenaar has to be extra-careful before accepting patches,
because once merged, the new code will be his responsibility.

These problems make it pretty hard to have new features and bug fixes merged
into the core. Vim just cant keep up with the development speed of its plugin
echosystem.

###Solution

Neovim is a vim fork that seeks to aggressively refactor vim in order to achieve
the following goals:

- Simplify maintenance to improve the speed that bug fixes and
  features get merged.
- Split the responsibility between multiple developers.
- Enable the implementation of new/modern user interfaces without any modifications
  to the core source. 
- Improve the extensibility power with a new plugin architecture based on
  external processes. Plugins will be written in any programming language
  without any explicit support from the editor. This can be saw as a better
  implementation of the [job control patch](https://groups.google.com/forum/#!topic/vim_dev/QF7Bzh1YABU)

Those goals should be achieved with little impact on vim's editing model or
vimscript in general. Most vimscript plugins should continue to work normally.

The following topics summarizes the major changes that will be performed:

* <a href="#legacy"><b>Legacy support and compile-time features</b></a>
* <a href="#platform"><b>Platform-specific code </b></a>
* <a href="#plugins"><b>New plugin architecture</b></a>
* <a href="#gui"><b>New GUI architecture</b></a>
* <a href="#split"><b>Split into many repositories</b></a>

<a name="legacy"></a>
##### Legacy support and compile-time features

Vim has a significant amount of code dedicated to supporting legacy systems and
compilers. All that code increases the maintainance burden and will be removed.

Most optional features will no longer be optional, with the exception of some
broken and useless fetures(eg: netbeans integration, sun workshop) which will be
removed permanently. Vi emulation will also be removed(probably leave the 'set
nocompatible' command as a no-op).

These changes wont affect most users. Those that only have a C89 compiler
installed or develop on legacy systems such as Amiga, BeOS or MSDOS have two
choices:

- Upgrade their software.
- Continue using vim

<a name="platform"></a>
##### Platform-specific code

Most of the platform-specific code will be removed and
[libuv](https://github.com/joyent/libuv) will be used to handle system
differences. libuv has support for most unixes and windows, so the vast
majority of vim's community will be supported.

<a name="plugins"></a>
##### New plugin architecture

All code supporting embedded scripting language interpreters will be replaced
by a new plugin system that will support extensions written in any programming
language.

Compatibility layers will be provided for easily porting vim plugins written in some
of the currently supported scripting languages such as python or ruby.

This is how the new plugin system will work:

- Plugins are long-running programs/jobs that communicate with vim through
  stdin/stdout using msgpack-rpc or json-rpc.
- Vim will discover and run these programs at startup, keeping two-way communication
  channels with each plugin.
- Plugins will be able to listen to events and send commands to vim
  asynchronously.

Here's a sample plugin session using [json-rpc](http://www.jsonrpc.org/specification) (jsonrpc version omitted):

```
plugin -> vim: {"id": 1, "method": "listenEvent", "params": {"eventName": "keyPressed"}}
vim -> plugin: {"id": 1, "result": true}
vim -> plugin: {"method": "event", "params": {"name": "keyPressed", "eventArgs": {"keys": ["C"]}}}
vim -> plugin: {"method": "event", "params": {"name": "keyPressed", "eventArgs": {"keys": ["Ctrl", "Space"]}}}
plugin -> vim: {"id": 2, "method": "showPopup", "params": {"size": {"width": 10, "height": 2} "position": {"column": 2, "line": 3}, "items": ["Completion1", "Completion2"]}}
plugin -> vim: {"id": 2, "result": true}}
```

That shows the conversation between vim and an hypotetical completion plugin
that popups completions when the user presses Ctrl+Space. The above scheme gives
neovim near limitless extensibility and also improves stability as plugins will
be automatically sandboxed from the main executable. 

This system can also easily emulate scripting languages interfaces to vim. A
plugin could, for example, emulate the current python interface by discovering
python scripts in vim's runtime dir and exposing a 'vim' module with an API
matching the current one. Calls to the API would simply be translated to
json-rpc messages sent to vim.


<a name="gui"></a>
##### New GUI architecture

Another contributing factor to vim's huge codebase is the explicit support for
dozens of widget toolkits for GUI interfaces. Like the legacy code support, gui
handling code will be removed from neovim's core.

Neovim will handle GUIs similarly to how it will handle plugins:

- GUIs are separate programs, possibly written in different programming
  languages.
- Neovim will use its own stdin/stdout to receive input and send updates, again
  using json-rpc or msgpack-rpc.

The difference between plugins and GUIs is that plugins will be started by
neovim, where GUIs will start neovim(or perhaps attach to a running session).
Here's a sample diagram of the process tree:

```txt
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

Sample:

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
  Windows or Ruby/Cocoa on Mac.
- Plugins will be able emit custom events that may be handled directly by GUIs.
  This will enable the implementaton of advanced features such as sublime's
  minimap. 
- A multiplexing daemon could could keep neovim instances running in a
  headless server, while multiple remote GUIs could attach/detach to share
  editing sessions.
- Neovim can be easily embedded into other programs.

<a name="split"></a>
##### Split into many repositories

Neovim's code will be split across many repositories in the [neovim
organization](https://github.com/neovim). There will be separate repositories
for GUIs, plugins, runtime files(official vimscript) and distributions. This
will let neovim will receive improvements much faster as the patches wont have
to pass through the approval of a single person.

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


