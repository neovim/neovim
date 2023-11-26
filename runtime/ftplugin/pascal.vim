" Vim filetype plugin file
" Language:		Pascal
" Maintainer:		Doug Kearns <dougkearns@gmail.com>
" Previous Maintainer:	Dan Sharp
" Last Change:		2021 Apr 23

if exists("b:did_ftplugin") | finish | endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

set comments=s:(*,m:\ ,e:*),s:{,m:\ ,e:}
set commentstring={%s}

if exists("pascal_delphi")
  set comments+=:///
endif

if !exists("pascal_traditional")
  set commentstring=//\ %s
  set comments+=://
endif

setlocal formatoptions-=t formatoptions+=croql

if exists("loaded_matchit")
  let b:match_ignorecase = 1 " (Pascal is case-insensitive)

  let b:match_words  = '\<\%(asm\|begin\|case\|\%(\%(=\|packed\)\s*\)\@<=\%(class\|object\)\|\%(=\s*\)\@<=interface\|record\|try\)\>'
  let b:match_words .= ':\%(^\s*\)\@<=\%(except\|finally\|else\|otherwise\)\>'
  let b:match_words .= ':\<end\>\.\@!'

  let b:match_words .= ',\<repeat\>:\<until\>'
  " let b:match_words .= ',\<if\>:\<else\>' " FIXME - else clashing with middle else. It seems like a debatable use anyway.
  let b:match_words .= ',\<unit\>:\<\%(\%(^\s*\)\@<=interface\|implementation\|initialization\|finalization\)\>:\<end\.'
endif

if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "Pascal Source Files (*.pas *.pp *.inc)\t*.pas;*.pp;*.inc\n" .
		     \ "All Files (*.*)\t*.*\n"
endif

let b:undo_ftplugin = "setl fo< cms< com< " ..
		    \ "| unlet! b:browsefilter b:match_words b:match_ignorecase"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: nowrap sw=2 sts=2 ts=8 noet:
