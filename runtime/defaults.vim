" defaults.vim
"
" some defaults set early on initialization.
"
" based on tpope's sensible.vim[1], with some suggestions gathered 
" at neovim's issue #276[2]
"
" [1]: https://github.com/tpope/vim-sensible
" [2]: https://github.com/neovim/neovim/issues/276

filetype plugin indent on
syntax enable

set autoindent
set backspace=indent,eol,start
set complete-=i
set smarttab

set nrformats-=octal

set ttimeout
set ttimeoutlen=100

set incsearch
set hlsearch
" use <C-L> to clear the highlighting of :set hlsearch.
nnoremap <silent> <C-L> :nohlsearch<CR><C-L>

set mouse=a

set laststatus=2
set ruler
set showcmd
set wildmenu
set wildmode=list:longest,full

set scrolloff=1
set sidescrolloff=5
set display+=lastline

set listchars=tab:>\ ,trail:-,extends:>,precedes:<,nbsp:+

set formatoptions+=j

" search upwards for tags file
setglobal tags-=./tags  tags^=./tags;

set autoread
set fileformats+=mac

set history=1000
set tabpagemax=50
set viminfo^=!
set sessionoptions-=options

" allow color schemes to do bright colors without forcing bold.
if &t_Co == 8 && $TERM !~# '^linux'
    set t_Co=16
endif

runtime! macros/matchit.vim
unlet g:loaded_matchit " allow a user installed matchit version to be resourced

" Y yanks to the end of the line 
noremap Y y$

" allow undoing <C-u> (delete text typed in the current line)
inoremap <C-U> <C-G>u<C-U>

" <home> goes to the beginning of the text on first press 
" and the beginning of the line on second. it alternates afterwards
noremap <expr> <home> virtcol('.') - 1 <= indent('.') && col('.') > 1 ? '0' : '_'
