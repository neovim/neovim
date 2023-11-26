" Vim filetype plugin
" Language:		awk, nawk, gawk, mawk
" Maintainer:		Doug Kearns <dougkearns@gmail.com>
" Previous Maintainer:	Antonio Colombo <azc100@gmail.com>
" Last Change:		2020 Sep 28

" This plugin was prepared by Mark Sikora
" This plugin was updated as proposed by Doug Kearns

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif

" Don't load another plugin for this buffer
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

setlocal comments=:#
setlocal commentstring=#\ %s
setlocal formatoptions-=t formatoptions+=croql

setlocal define=function
setlocal suffixesadd+=.awk

let b:undo_ftplugin = "setl fo< com< cms< def< sua<" .
		    \ " | unlet! b:browsefilter"

" TODO: set this in scripts.vim?
if exists("g:awk_is_gawk")
  setlocal include=@include
  setlocal suffixesadd+=.gawk
  if has("unix") || has("win32unix")
    setlocal formatprg=gawk\ -f-\ -o/dev/stdout
    let b:undo_ftplugin .= " | setl fp<"
  endif

  " Disabled by default for security reasons.
  if dist#vim#IsSafeExecutable('awk', 'gawk')
    let path = system("gawk 'BEGIN { printf ENVIRON[\"AWKPATH\"] }'")
    let path = substitute(path, '^\.\=:\|:\.\=$\|:\.\=:', ',,', 'g') " POSIX cwd
    let path = substitute(path, ':', ',', 'g')

    let &l:path = path
  endif
  let b:undo_ftplugin .= " | setl inc< path<"
endif

if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "Awk Source Files (*.awk,*.gawk)\t*.awk;*.gawk\n" .
		     \ "All Files (*.*)\t*.*\n"
endif

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: nowrap sw=2 sts=2 ts=8
