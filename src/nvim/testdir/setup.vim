" Common preparations for running tests.

" Only load this once.
if 1
  if exists('s:did_load')
    finish
  endif
  let s:did_load = 1
endif

" Make sure 'runtimepath' and 'packpath' does not include $HOME.
set rtp=$VIM/vimfiles,$VIMRUNTIME,$VIM/vimfiles/after
if has('packages')
  let &packpath = &rtp
endif

" Only when the +eval feature is present. 
if 1
  " Make sure the .Xauthority file can be found after changing $HOME.
  if $XAUTHORITY == ''
    let $XAUTHORITY = $HOME . '/.Xauthority'
  endif

  " Avoid storing shell history.
  let $HISTFILE = ""

  " Nvim: detect user modules for language providers (before changing $HOME).
  let $PYTHONUSERBASE = $HOME . '/.local'
  if executable('gem')
    let $GEM_PATH = system('gem env gempath')
  endif

  " Make sure $HOME does not get read or written.
  " It must exist, gnome tries to create $HOME/.gnome2
  let $HOME = getcwd() . '/XfakeHOME'
  if !isdirectory($HOME)
    call mkdir($HOME)
  endif
endif

source unix.vim

" Align Nvim defaults to Vim.
set backspace=
set directory^=.
set fillchars=vert:\|,fold:-
set laststatus=1
set listchars=eol:$
set nohidden smarttab noautoindent noautoread complete-=i noruler noshowcmd
set nrformats+=octal
set shortmess-=F
set sidescroll=0
set tags=./tags,tags
set undodir^=.
set wildoptions=

" Prevent Nvim log from writing to stderr.
let $NVIM_LOG_FILE = exists($NVIM_LOG_FILE) ? $NVIM_LOG_FILE : 'Xnvim.log'

" Don't depend on system locale, always use utf-8.
" Ref: https://github.com/neovim/neovim/pull/2929
set encoding=utf-8

" Use default shell on Windows to avoid segfault, caused by TUI
if has('win32')
  let $SHELL = ''
  let $TERM = ''
  let &shell = empty($COMSPEC) ? exepath('cmd.exe') : $COMSPEC
  set shellcmdflag=/s/c shellxquote=\" shellredir=>%s\ 2>&1
  let &shellpipe = &shellredir
endif
