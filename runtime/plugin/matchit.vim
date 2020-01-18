" Nvim: load the matchit plugin by default.
if stridx(&packpath, $VIMRUNTIME) >= 0
  packadd matchit
endif
