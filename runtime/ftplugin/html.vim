" Vim filetype plugin file
" Language:	html
"
" This runtime file is looking for a new maintainer.
"
" Former maintainer:	Dan Sharp
" Last Changed: 20 Jan 2009

if exists("b:did_ftplugin") | finish | endif
let b:did_ftplugin = 1

" Make sure the continuation lines below do not cause problems in
" compatibility mode.
let s:save_cpo = &cpo
set cpo-=C

setlocal matchpairs+=<:>
setlocal commentstring=<!--%s-->
setlocal comments=s:<!--,m:\ \ \ \ ,e:-->

if exists("g:ft_html_autocomment") && (g:ft_html_autocomment == 1)
    setlocal formatoptions-=t formatoptions+=croql
endif

if exists('&omnifunc')
  setlocal omnifunc=htmlcomplete#CompleteTags
  call htmlcomplete#DetectOmniFlavor()
endif

" HTML:  thanks to Johannes Zellner and Benji Fisher.
if exists("loaded_matchit")
    let b:match_ignorecase = 1
    let b:match_words = '<:>,' .
    \ '<\@<=[ou]l\>[^>]*\%(>\|$\):<\@<=li\>:<\@<=/[ou]l>,' .
    \ '<\@<=dl\>[^>]*\%(>\|$\):<\@<=d[td]\>:<\@<=/dl>,' .
    \ '<\@<=\([^/][^ \t>]*\)[^>]*\%(>\|$\):<\@<=/\1>'
endif

" Change the :browse e filter to primarily show HTML-related files.
if has("gui_win32")
    let  b:browsefilter="HTML Files (*.html,*.htm)\t*.htm;*.html\n" .
		\	"JavaScript Files (*.js)\t*.js\n" .
		\	"Cascading StyleSheets (*.css)\t*.css\n" .
		\	"All Files (*.*)\t*.*\n"
endif

" Undo the stuff we changed.
let b:undo_ftplugin = "setlocal commentstring< matchpairs< omnifunc< comments< formatoptions<" .
    \	" | unlet! b:match_ignorecase b:match_skip b:match_words b:browsefilter"

" Restore the saved compatibility options.
let &cpo = s:save_cpo
unlet s:save_cpo
