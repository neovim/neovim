" Assume 'encoding' is set to "latin1" while actually cp1253 or iso-8859-7 is
" being used
if has("win16") || has("win32") || has("win32unix")
  source <sfile>:p:h/greek_cp1253.vim
else
  source <sfile>:p:h/greek_iso-8859-7.vim
endif
