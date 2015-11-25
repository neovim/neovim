# YouCompleteMe Integration

## What is this?

This provides the code necessary to configure vim's YCM plugin to provide C semantic support (completion, go-to-definition, etc) for developers working on the Neovim project.

## Installation

### Step 1

Install [YouCompleteMe](https://github.com/Valloric/YouCompleteMe).

### Step 2

```bash
cp contrib/YouCompleteMe/ycm_extra_conf.py src/.ycm_extra_conf.py
echo .ycm_extra_conf.py >> .git/info/exclude
make

(Add the following somewhere in your vimrc)
autocmd FileType c nnoremap <buffer> <silent> <C-]> :YcmCompleter GoTo<cr>
```
