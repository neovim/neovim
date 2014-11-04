# localvimrc

## Installation

### Step 1

Install [vim-localvimrc](https://github.com/embear/vim-localvimrc).

For example, using [vim-plug](https://github.com/junegunn/vim-plug):
```vim
Plug 'embear/vim-localvimrc'
```

### Step 2

Add `contrib/localvimrc/vimrc.local` to your list of localvimrc candidates:
```vim
let g:localvimrc_name = [".vimrc.local", "contrib/localvimrc/vimrc.local"]
```
