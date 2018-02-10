" Common preparations for running tests.

" Align Nvim defaults to Vim.
set sidescroll=0
set directory^=.
set backspace=
set nohidden smarttab noautoindent noautoread complete-=i noruler noshowcmd
set listchars=eol:$
" Prevent Nvim log from writing to stderr.
let $NVIM_LOG_FILE = exists($NVIM_LOG_FILE) ? $NVIM_LOG_FILE : 'Xnvim.log'


" Make sure 'runtimepath' and 'packpath' does not include $HOME.
set rtp=$VIM/vimfiles,$VIMRUNTIME,$VIM/vimfiles/after
let &packpath = &rtp

" Make sure $HOME does not get read or written.
let $HOME = '/does/not/exist'
