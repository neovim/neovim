" Vim filetype plugin file
" Language:	bash
" Maintainer:	Bram Moolenaar
" Last Changed: 2019 Jan 12
"
" This is not a real filetype plugin.  It allows for someone to set 'filetype'
" to "bash" in the modeline, and gets the effect of filetype "sh" with
" b:is_bash set.  Idea from Mahmode Al-Qudsi.

if exists("b:did_ftplugin")
  finish
endif

let b:is_bash = 1
if exists("b:is_sh")
  unlet b:is_sh
endif
if exists("b:is_kornshell")
  unlet b:is_kornshell
endif

" Setting 'filetype' here directly won't work, since we are being invoked
" through an autocommand.  Do it later, on the BufWinEnter event.
augroup bash_filetype
  au BufWinEnter * call SetBashFt()
augroup END

func SetBashFt()
  au! bash_filetype
  set ft=sh
endfunc
