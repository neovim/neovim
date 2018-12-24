# vimspector - A multi language graphical debugger for Vim

# Status

The plugin is a capable Vim graphical debugger for multiple languages.
It's mostly tested for c++ and python, but in theory supports any 
language that Visual Studio Code supports (but see caveats).

It supports:

- breakpoints (function and line)
- step in/out/over/up, stop, restart
- launch and attach
- locals and globals display
- watches (expressions)
- call stack and navigation
- variable value display hover
- interractive debug console
- launch debugee within Vim's embedded terminal
- logging/stdout display

The author successfully uses it for debugging Vim code and YouCompletMe's
core engine `ycmd` (a complex python application).

It should work for any debug adapter that works in VSCode, but there are
certain limitations (see FAQ). There are some bugs certainly, and 
configuring it is a bit of a dark art at this stage.

It is currently a work in progress, and any feedback/contributions are more
than welcome.

If you are insanely curious and wish to try it out, it's probably best to
shout me in the [vimspector gitter channel][gitter]. I'd love to hear from
you.

In order to use it you have to currently:

- Write an undocumented configuration file that contains essentially
  undocumented parameters.
- Use an undocumented API via things like `:call vimsepctor#Launch()`.
- Accept that it isn't complete yet
- etc.

## Experimental

The plugin is currently _experimental_. That means that any part of it
can (and probably will) change, including things like:

- breaking changes to the configuration
- keys, layout, functionatlity of the UI

If a large number of people start using it then I will do my best to
minimise this, or at least announce on Gitter.

# Background

The motivation is that debugging in Vim is a pretty horrible experience,
particularly if you use multiple languages. With pyclewn no more and the
built-in termdebug plugin limited to gdb, I wanted to explore options.

While Language Server Protocol is well known, the Debug Adapter Protocol is less
well known, but achieves a similar goal: language agnostic API abstracting
debuggers from clients.

The aim of this project is to provide a simple but effective debugging
experience in Vim for multiple languages, by leveraging the debug adapters that
are being built for Visual Studio Code.

The ability to do remote debugging is a must. This is key to my workflow, so
baking it in to the debugging experience is a top bill goal for the project.

# Demo

Please note the entire UI is placeholder. These are just proofs-of-concept.

## C Debugging

![C demo](https://cdn.pbrd.co/images/Hnk0NfR.gif)

# Python Debugging

![demo-python](https://cdn.pbrd.co/images/Hnk5ZPw.gif)

# Features and Usage

## Launch and attach by PID:

* Create `vimspector.json`. See [below](#supported-languages).
* `:call vimsepctor#Launch()` and select a configuration.

## Breakpoints

* Use `vimspector#ToggleBreakpoint()` to set/disable/delete a line breakpoint.
* Use `vimspector#AddFunctionBreakpoint( '<name>' )` to add a function
breakpoint.

## Stepping

* Step in/out, finish, continue, pause etc. using the WinBar.
* If you really want to, the API is `vimspector#StepInto()` etc.

## Variables and scopes

* Current scope shows values of locals.
* Use `<CR>` to expand/collapse (+, -).
* When changing the stack frame the locals window updates.
* While paused, hover to see values

## Watches

The watches window is a prompt buffer. Enter insert mode to add a 
new watch expression.

* Add watches to the variables window by entering insert mode and
  typing the expression. Commit with `<CR>`.
* Expand result with `<CR>`.
* Delete with `<DEL>`.

## Stack Traces

* In the threads window, use `<CR>` to expand/collapse.
* Use `<CR>` on a stack frame to jump to it.

## Program Output:

* In the outputs window use the WinBar to select the output channel.
* The debugee prints to the stdout channel.
* Other channels may be useful for debugging.

### Console

The console window is a prompt buffer and can be used as an interactive
CLI for the debug adapter. Support for this varies amongt adapters.

* Enter insert mode to enter a command to evaluate
* Commit the request with `<CR>`
* The request and subsequent result are printed.

NOTE: See also [Watches][#watches] above.

# Supported Languages

Current tested with the following debug adapters.

Note, there is no support for installing the extension. Use VSCode to do that by
installing it in the UI. The default extension directory is something like
`$HOME/.vscode/extensions`.

Note, the launch configurations below are reverse-engineered from the
extensions. Typically they are documented in the extension's `package.json`, but
not always (or not completely).

* C++: [vscode-cpptools](https://github.com/Microsoft/vscode-cpptools)

```
{
  "adapters": {
    "cppdbg": {
      "name": "cppdbg",
      "command": [ "<path to extension>/debugAdapters/OpenDebugAD7" ],
      "attach": {
        "pidProperty": "processId",
        "pidSelect": "ask"
      }
    },
    ....
  },
  "configurations": {
    "<name>: Launch": {
      "adapter": "cppdbg",
      "configuration": {
        "name": "<name>",
        "type": "cppdbg",
        "request": "launch",
        "program": "<path to binary>",
        "args": [ ... ],
        "cwd": "<working directory>",
        "environment": [ ... ],
        "externalConsole": true,
        "MIMode": "lldb"
      }
    },
    "<name>: Attach": {
      "adapter": "cppdbg",
      "configuration": {
        "name": "<name>: Attach",
        "type": "cppdbg",
        "request": "attach",
        "program": "<path to binary>",
        "MIMode": "lldb"
      }
    }
    ...
  }
}
```

* C++: [code=debug ](https://github.com/WebFreak001/code-debug)

```
{
  "adapters": {
    "lldb-mi": {
      "name": "lldb-mi",
      "command": [
        "node",
        "<path to extension>/out/src/lldb.js"
      ],
      "attach": {
        "pidProperty": "target",
        "pidSelect": "ask"
      }
    }
    ...
  },
  "configurations": {
    "<name>: Launch": {
      "adapter": "lldb-mi",
      "configuration": {
        "request": "attach",
        "cwd": "<working directory>",
        "program": "<path to binary>",
        "args": [ ... ],
        "environment": [ ... ],
        "lldbmipath": "<path to a working lldb-mi>"
      }
    },
    "<name>: Attach": {
      "adapter": "lldb-mi",
      "configuration": {
        "request": "attach",
        "cwd": "<working directory>",
        "executable": "<path to binary>",
        "lldbmipath": "<path to a working lldb-mi>"
      }
    }
    ...
  }
}

```

* C, C++, Rust, etc.: [CodeLLDB](https://github.com/vadimcn/vscode-lldb)

```
{
  "adapters": {
    "lldb": {
      "name": "lldb",
      "command": [
        "lldb",
        "-b",
        "-O",
        "command script import '<extension path>/adapter'",
        "-O",
        "script adapter.main.run_stdio_session()"
      ]
    }
    ...
  },
  "configurations": {
    "<name>: Launch": {
      "adapter": "lldb",
      "configuration": {
        "type": "lldb",
        "request": "launch",
        "name": "<name>: Launch",
        "program": "<path to binary>",
        "args": [ .. ],
        "cwd": "<working directory>"
      }
    }
  }
}
```

* Python: [vscode-python](https://github.com/Microsoft/vscode-python)

```
{
  "adapters": {
    "python": {
      "name": "python",
      "command": [
        "node",
        "<path to extension>/out/client/debugger/debugAdapter/main.js"
      ]
    }
    ...
  },
  "configurations": {
    "<name>: Launch": {
      "adapter": "python",
      "configuration": {
        "name": "<name>: Launch",
        "type": "python",
        "request": "launch",
        "cwd": "<working directory>",
        "stopOnEntry": true,
        "console": "externalTerminal",
        "debugOptions": [],
        "program": "<path to main python file>"
      }
    }
    ...
  }
}
```

Also the mock debugger, but that isn't actually useful.

# Unsupported

Known not to work:

* Java Debug Server. The [java debug server][java-debug-server] runs as a
  jdt.ls plugin, rather than a standalone debug adapter. This makes a lot
  of sense if you already happen to be running the language server. 
  Vimspector is not in the business of running language servers. So, rather
  than doing so, vimspector simply allows you to start the java debug server
  manually (however you might do so) and you can tell vimspector the port
  on which it is listening. See [this issue](https://github.com/puremourning/vimspector/issues/3)
  for more background.
* C-sharp. The license appears to require that it is only used with Visual
  Studio Code.

# Supported Platforms

Currently on the author's environment which is macOS.

The plugin _might_ work on other UNIX-like environments but it hasn't been
tested. It will almost certainly not work on Windows.

Requires:

- Vim 8.1 compiled with python 3 support.

Note the plugin uses a lot of very new Vim features (like prompt buffers), so
I would strongly recommend a very new build of Vim.

# FAQ

1. Q: Does it work? A: Yeah, sort of. It's _incredibly_ buggy and unpolished.
2. Q: Does it work with <insert language here>? A: Probably, but it won't
   necessarily be easy to work out what to put in the `.vimspector.json`. As you
   can see above, some of the servers aren't really editor agnostic, and require
   very-specific unique handling.

# License

[Apache 2.0](http://www.apache.org/licenses/LICENSE-2.0)

Copyright © 2018 Ben Jackson

[ycmd]: https://github.com/Valloric/ycmd
[gitter]: https://gitter.im/vimspector/Lobby?utm_source=share-link&utm_medium=link&utm_campaign=share-link
