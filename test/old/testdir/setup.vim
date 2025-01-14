if exists('s:did_load')
  " Align Nvim defaults to Vim.
  set commentstring=/*\ %s\ */
  set complete=.,w,b,u,t,i
  set define=^\\s*#\\s*define
  set directory^=.
  set display=
  set fillchars=vert:\|,foldsep:\|,fold:-
  set formatoptions=tcq
  set fsync
  set include=^\\s*#\\s*include
  set laststatus=1
  set listchars=eol:$
  set joinspaces
  set jumpoptions=
  set mousemodel=extend
  set nohidden nosmarttab noautoindent noautoread noruler noshowcmd
  set nohlsearch noincsearch
  set nrformats=bin,octal,hex
  set shortmess=filnxtToOS
  set sidescroll=0
  set tags=./tags,tags
  set undodir^=.
  set wildoptions=
  set startofline
  set sessionoptions+=options
  set viewoptions+=options
  set switchbuf=
  if has('win32')
    set isfname+=:
  endif
  if g:testname !~ 'test_mapping.vim$'
    " Make "Q" switch to Ex mode.
    " This does not work for all tests as Nvim only supports Vim Ex mode.
    nnoremap Q gQ<Cmd>call<SID>ExStart()<CR>
  endif
endif

" Common preparations for running tests.

" Only load this once.
if exists('s:did_load')
  finish
endif
let s:did_load = 1

func s:ExStart()
  call feedkeys($"\<Cmd>call{expand('<SID>')}ExMayEnd()\<CR>")
endfunc

func s:ExMayEnd()
  " When :normal runs out of characters in Vim, the behavior is different in
  " normal Ex mode vs. Vim Ex mode.
  " - In normal Ex mode, "\n" is used.
  " - In Vim Ex mode, Ctrl-C is used.
  " Nvim only supports Vim Ex mode, so emulate the normal Ex mode behavior.
  if state('m') == '' && mode(1) == 'cv' && getcharstr(1) == "\<C-C>"
    call feedkeys("\n")
  endif
endfunc

" Clear Nvim default user commands, mappings and menus.
comclear
mapclear
mapclear!
aunmenu *
tlunmenu *
autocmd! nvim.popupmenu

" Undo the 'grepprg' and 'grepformat' setting in _defaults.lua.
set grepprg& grepformat&

" roughly equivalent to test_setmouse() in Vim
func Ntest_setmouse(row, col)
  call nvim_input_mouse('move', '', '', 0, a:row - 1, a:col - 1)
  if state('m') == ''
    call getchar(0)
  endif
endfunc

" roughly equivalent to term_wait() in Vim
func Nterm_wait(buf, time = 10)
  execute $'sleep {a:time}m'
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

" Use Vim's default color scheme
colorscheme vim
