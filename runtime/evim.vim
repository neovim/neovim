" Vim script for Evim key bindings
" Maintainer:	Bram Moolenaar <Bram@vim.org>
" Last Change:	2006 Mar 29

" Don't use Vi-compatible mode.
set nocompatible

" Use the mswin.vim script for most mappings
source <sfile>:p:h/mswin.vim

" Vim is in Insert mode by default
set insertmode

" Make a buffer hidden when editing another one
set hidden

" Make cursor keys ignore wrapping
inoremap <silent> <Down> <C-R>=pumvisible() ? "\<lt>Down>" : "\<lt>C-O>gj"<CR>
inoremap <silent> <Up> <C-R>=pumvisible() ? "\<lt>Up>" : "\<lt>C-O>gk"<CR>

" CTRL-F does Find dialog instead of page forward
noremap <silent> <C-F> :promptfind<CR>
vnoremap <silent> <C-F> y:promptfind <C-R>"<CR>
onoremap <silent> <C-F> <C-C>:promptfind<CR>
inoremap <silent> <C-F> <C-O>:promptfind<CR>
cnoremap <silent> <C-F> <C-C>:promptfind<CR>


set backspace=2		" allow backspacing over everything in insert mode
set autoindent		" always set autoindenting on
if has("vms")
  set nobackup		" do not keep a backup file, use versions instead
else
  set backup		" keep a backup file
endif
set history=50		" keep 50 lines of command line history
set ruler		" show the cursor position all the time
set incsearch		" do incremental searching
set mouse=a		" always use the mouse

" Don't use Ex mode, use Q for formatting
map Q gq

" Switch syntax highlighting on, when the terminal has colors
" Highlight the last used search pattern on the next search command.
if &t_Co > 2 || has("gui_running")
  syntax on
  set hlsearch
  nohlsearch
endif

" Only do this part when compiled with support for autocommands.
if has("autocmd")

  " Enable file type detection.
  " Use the default filetype settings, so that mail gets 'tw' set to 72,
  " 'cindent' is on in C files, etc.
  " Also load indent files, to automatically do language-dependent indenting.
  filetype plugin indent on

  " For all text files set 'textwidth' to 78 characters.
  au FileType text setlocal tw=78

endif " has("autocmd")

" vim: set sw=2 :
