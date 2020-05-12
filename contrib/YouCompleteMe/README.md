# YouCompleteMe Integration

## What is this?

This provides the code necessary to configure vim's YCM plugin to provide C
semantic support (completion, go-to-definition, etc) for developers working on
the Neovim project.

## Installation

### Step 1

Install [YouCompleteMe](https://github.com/Valloric/YouCompleteMe).

### Step 2

```bash
cp contrib/YouCompleteMe/ycm_extra_conf.py .ycm_extra_conf.py
echo .ycm_extra_conf.py >> .git/info/exclude
make
```

Tip: to improve source code navigation, add something like this to your nvim
configuration:

```vim
au FileType c,cpp nnoremap <buffer> <c-]> :YcmCompleter GoTo<CR>
```

And use `ctrl+]` when the cursor is positioned in a symbol to quickly jump to a
definition or declaration.
