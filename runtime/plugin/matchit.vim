" Nvim: load the matchit plugin by default.
if !exists("g:loaded_matchit") && stridx(&packpath, $VIMRUNTIME) >= 0
  packadd matchit
endif
