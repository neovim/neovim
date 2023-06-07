if exists('s:did_load')
  " Align Nvim defaults to Vim.
  set backspace=
  set commentstring=/*%s*/
  set complete=.,w,b,u,t,i
  set define=^\\s*#\\s*define
  set directory&
  set directory^=.
  set display=
  set fillchars=vert:\|,foldsep:\|,fold:-
  set formatoptions=tcq
  set fsync
  set include=^\\s*#\\s*include
  set laststatus=1
  set listchars=eol:$
  set joinspaces
  set mousemodel=extend
  set nohidden nosmarttab noautoindent noautoread noruler noshowcmd
  set nohlsearch noincsearch
  set nrformats=bin,octal,hex
  set shortmess=filnxtToOS
  set sidescroll=0
  set tags=./tags,tags
  set undodir&
  set undodir^=.
  set wildoptions=
  set startofline
  set sessionoptions&
  set sessionoptions+=options
  set viewoptions&
  set viewoptions+=options
  set switchbuf=
  if g:testname !~ 'test_mapping.vim$'
    " Make "Q" switch to Ex mode.
    " This does not work for all tests.
    nnoremap Q gQ
  endif
endif

" Common preparations for running tests.

" Only load this once.
if exists('s:did_load')
  finish
endif
let s:did_load = 1

" Clear Nvim default mappings and menus.
mapclear
mapclear!
aunmenu *
tlunmenu *

" roughly equivalent to test_setmouse() in Vim
func Ntest_setmouse(row, col)
  call nvim_input_mouse('move', '', '', 0, a:row - 1, a:col - 1)
endfunc

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
