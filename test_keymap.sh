#!/bin/bash

# Run the keymap functional test.
#
# To run with gdbserver,
# $ export GDB=1
# $ ./test_keymap.sh
#
# Run GDB in another terminal,
# $ (gdb) target remote localhost:7777
# $ (gdb) continue
#
# GDB will load remote symbols, then apparently freeze? It's still possible to
# interrupt using CTRL-C, and step, set breakpoints, and so on.

TEST_FILE='test/functional/api/keymap_spec.lua' make functionaltest
