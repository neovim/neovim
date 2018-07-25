" Common preparations for running tests.

" Only load this once.
if exists('s:did_load')
  finish
endif
let s:did_load = 1

" Align Nvim defaults to Vim.
set sidescroll=0
set directory^=.
set backspace=
set nohidden smarttab noautoindent noautoread complete-=i noruler noshowcmd
set listchars=eol:$
set fillchars=vert:\|,fold:-
" Prevent Nvim log from writing to stderr.
let $NVIM_LOG_FILE = exists($NVIM_LOG_FILE) ? $NVIM_LOG_FILE : 'Xnvim.log'


" Make sure 'runtimepath' and 'packpath' does not include $HOME.
set rtp=$VIM/vimfiles,$VIMRUNTIME,$VIM/vimfiles/after
let &packpath = &rtp

" Make sure $HOME does not get read or written.
let $HOME = expand(getcwd() . '/XfakeHOME')
if !isdirectory($HOME)
  call mkdir($HOME)
endif

" Use default shell on Windows to avoid segfault, caused by TUI
if has('win32')
  let $SHELL = ''
  let $TERM = ''
  let &shell = empty($COMSPEC) ? exepath('cmd.exe') : $COMSPEC
  set shellcmdflag=/s/c shellxquote=\" shellredir=>%s\ 2>&1
endif
