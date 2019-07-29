" Settings for test script execution
" Always use "sh", don't use the value of "$SHELL".
set shell=sh

if has('win32')
  set shellcmdflag=-c shellxquote= shellxescape= shellquote=
  let &shellredir = '>%s 2>&1'
endif
