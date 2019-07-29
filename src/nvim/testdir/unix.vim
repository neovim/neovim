" Settings for test script execution
" Always use "sh", don't use the value of "$SHELL".
set shell=sh

" Only when the +eval feature is present. 
if 1
  " While some tests overwrite $HOME to prevent them from polluting user files,
  " we need to remember the original value so that we can tell external systems
  " where to ask about their own user settings.
  let g:tester_HOME = $HOME
endif

source setup.vim

" TODO: upstream?
" Initially added in https://github.com/neovim/neovim/commit/4a5bc6275d090.
" Appears to make sense as in "adjust for set shell=sh".
if has('win32')
  set shellcmdflag=-c shellxquote= shellxescape= shellquote=
  let &shellredir = '>%s 2>&1'
endif
