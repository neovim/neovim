" Common preparations for running tests.

" Only load this once.
if exists('s:did_load')
  finish
endif
let s:did_load = 1

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


" Make sure 'runtimepath' and 'packpath' does not include $HOME.
set rtp=$VIM/vimfiles,$VIMRUNTIME,$VIM/vimfiles/after
let &packpath = &rtp

" Avoid storing shell history.
let $HISTFILE = ""

" Use default shell on Windows to avoid segfault, caused by TUI
if has('win32')
  let $SHELL = ''
  let $TERM = ''
  let &shell = empty($COMSPEC) ? exepath('cmd.exe') : $COMSPEC
  set shellcmdflag=/s/c shellxquote=\" shellredir=>%s\ 2>&1
  let &shellpipe = &shellredir
endif

" Detect user modules for language providers
let $PYTHONUSERBASE = $HOME . '/.local'
if executable('gem')
  let $GEM_PATH = system('gem env gempath')
endif

" Make sure $HOME does not get read or written.
let $HOME = expand(getcwd() . '/XfakeHOME')
if !isdirectory($HOME)
  call mkdir($HOME)
endif
