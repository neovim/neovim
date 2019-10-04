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

" Nvim: we are using "-u NONE" (to disable syntax etc reliably).
" Configuration for Unix (Vim's unix.vim) / win32 (Vim's dos.vim).
if has('win32')
  " Native Windows build.
  " TODO: allow for use of shell=sh also on MingW builds etc (via env var,
  " NVIM_TEST_SHELL)?
  let $SHELL = ''
  let $TERM = ''
  let &shell = empty($COMSPEC) ? exepath('cmd.exe') : $COMSPEC
  set shellcmdflag=/s/c shellxquote=\" shellredir=>%s\ 2>&1
  let &shellpipe = &shellredir
else
  " Always use "sh", don't use the value of "$SHELL".
  set shell=sh

  " Adjust for "set shell=sh" (done in Vim automatically, but not Nvim).
  set shellcmdflag=-c shellxquote= shellxescape= shellquote=
  let &shellredir = '>%s 2>&1'
  set shellslash
endif

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

" Use safer defaults for various directories (below $TMPDIR).
for d in ['backupdir', 'directory', 'undodir', 'viewdir']
  exe printf('set %s^=%s', d, $TMPDIR.'/'.d)
endfor

if exists('syntax_on')
  call assert_report('syntax_on exists: tests should be run with -u NONE!')
endif

" Prevent Nvim log from writing to stderr.
let $NVIM_LOG_FILE = exists($NVIM_LOG_FILE) ? $NVIM_LOG_FILE : 'Xnvim.log'
