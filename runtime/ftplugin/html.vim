" Vim filetype plugin file
" Language:		HTML
" Maintainer:		Doug Kearns <dougkearns@gmail.com>
" Previous Maintainer:	Dan Sharp
" Last Change:		2024 Jan 14
" 			2024 May 24 by Riley Bruins <ribru17@gmail.com> ('commentstring')

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:save_cpo = &cpo
set cpo-=C

setlocal matchpairs+=<:>
setlocal commentstring=<!--\ %s\ -->
setlocal comments=s:<!--,m:\ \ \ \ ,e:-->

let b:undo_ftplugin = "setlocal comments< commentstring< matchpairs<"

if get(g:, "ft_html_autocomment", 0)
  setlocal formatoptions-=t formatoptions+=croql
  let b:undo_ftplugin ..= " | setlocal formatoptions<"
endif

if exists('&omnifunc')
  setlocal omnifunc=htmlcomplete#CompleteTags
  call htmlcomplete#DetectOmniFlavor()
  let b:undo_ftplugin ..= " | setlocal omnifunc<"
endif

" HTML: thanks to Johannes Zellner and Benji Fisher.
if exists("loaded_matchit") && !exists("b:match_words")
  let b:match_ignorecase = 1
  let b:match_words = '<!--:-->,' ..
	\	      '<:>,' ..
	\	      '<\@<=[ou]l\>[^>]*\%(>\|$\):<\@<=li\>:<\@<=/[ou]l>,' ..
	\	      '<\@<=dl\>[^>]*\%(>\|$\):<\@<=d[td]\>:<\@<=/dl>,' ..
	\	      '<\@<=\([^/!][^ \t>]*\)[^>]*\%(>\|$\):<\@<=/\1>'
  let b:html_set_match_words = 1
  let b:undo_ftplugin ..= " | unlet! b:match_ignorecase b:match_words b:html_set_match_words"
endif

" Change the :browse e filter to primarily show HTML-related files.
if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let  b:browsefilter = "HTML Files (*.html, *.htm)\t*.html;*.htm\n" ..
	\		"JavaScript Files (*.js)\t*.js\n" ..
	\		"Cascading StyleSheets (*.css)\t*.css\n"
  if has("win32")
    let b:browsefilter ..= "All Files (*.*)\t*\n"
  else
    let b:browsefilter ..= "All Files (*)\t*\n"
  endif
  let b:html_set_browsefilter = 1
  let b:undo_ftplugin ..= " | unlet! b:browsefilter b:html_set_browsefilter"
endif

let &cpo = s:save_cpo
unlet s:save_cpo
