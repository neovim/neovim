# NeoVim LLCM/Clang RPC Metadata Plugin

## Prerequisites

The one dependency is LLVM/Clang and Clang compiler.

## Usage

```bash
$ clang \
    -c \
    -std=gnu99 \
    -DDEFINE_FUNC_ATTRIBUTES \
    -I/path/to/neovim/repository/src \
    -I/path/to/neovim/repository/build/directory/config \
    -I/path/to/neovim/repository/build/directory/src \
    -Xclang -load -Xclang $(pwd)/build/debug/neovim-metadata.so -Xclang -plugin -Xclang neovim-metadata \
    samples/buffer.c 2> /dev/null
```
