# vimspector - A multi language debugger for Vim

# Status

This is a work in progress. It barely functions.

# About

The motivation is that debugging in Vim is a pretty horrible experience,
particularly if you use multiple languages. With pyclewn no more and the
built-in termdebug plugin limited to gdb, I wanted to explore options.

While Language Server Protocol is well known, the Debug Adapter Protocol is less
well known, but achieves a similar goal: language agnostic API abstracting
debuggers from clients.

The aim of this project is to provide a simple but effective debugging
experience in Vim for multiple languages, by leveraging the debug adapters that
are being built for VScode.

The ability to do remote debugging is a must. This is key to my workflow, so
baking it in to the debugging experience is a top bill goal for the project.

# Features

None yet.

# Supported Languages

None yet.

# Demo

None yet.

OK, well there is [a proof of
concept](https://files.gitter.im/Valloric/ycmd/BUVt/vimspector-first-demo.gif).

# FAQ

1. Q: Does it work? A: Not yet.

# License

[Apache 2.0](http://www.apache.org/licenses/LICENSE-2.0)

Copyright © 2018 Ben Jackson
