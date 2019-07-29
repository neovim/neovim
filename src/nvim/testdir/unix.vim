" Settings for test script execution
" Always use "sh", don't use the value of "$SHELL".
set shell=sh

if has('win32')
  set shellcmdflag=-c shellxquote= shellxescape= shellquote=
  let &shellredir = '>%s 2>&1'
endif

" Don't depend on system locale, always use utf-8
set encoding=utf-8
