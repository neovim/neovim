" Vim filetype plugin file
" Language:	php
"
" This runtime file is looking for a new maintainer.
"
" Former maintainer:	Dan Sharp
" Last Changed: 20 Jan 2009

if exists("b:did_ftplugin") | finish | endif

" Make sure the continuation lines below do not cause problems in
" compatibility mode.
let s:keepcpo= &cpo
set cpo&vim

" Define some defaults in case the included ftplugins don't set them.
let s:undo_ftplugin = ""
let s:browsefilter = "HTML Files (*.html, *.htm)\t*.html;*.htm\n" .
	    \	     "All Files (*.*)\t*.*\n"
let s:match_words = ""

runtime! ftplugin/html.vim ftplugin/html_*.vim ftplugin/html/*.vim
let b:did_ftplugin = 1

" Override our defaults if these were set by an included ftplugin.
if exists("b:undo_ftplugin")
    let s:undo_ftplugin = b:undo_ftplugin
endif
if exists("b:browsefilter")
    let s:browsefilter = b:browsefilter
endif
if exists("b:match_words")
    let s:match_words = b:match_words
endif
if exists("b:match_skip")
    unlet b:match_skip
endif

" Change the :browse e filter to primarily show PHP-related files.
if has("gui_win32")
    let  b:browsefilter="PHP Files (*.php)\t*.php\n" . s:browsefilter
endif

" ###
" Provided by Mikolaj Machowski <mikmach at wp dot pl>
setlocal include=\\\(require\\\|include\\\)\\\(_once\\\)\\\?
" Disabled changing 'iskeyword', it breaks a command such as "*"
" setlocal iskeyword+=$

if exists("loaded_matchit")
    let b:match_words = '<?php:?>,\<switch\>:\<endswitch\>,' .
		      \ '\<if\>:\<elseif\>:\<else\>:\<endif\>,' .
		      \ '\<while\>:\<endwhile\>,' .
		      \ '\<do\>:\<while\>,' .
		      \ '\<for\>:\<endfor\>,' .
		      \ '\<foreach\>:\<endforeach\>,' .
                      \ '(:),[:],{:},' .
		      \ s:match_words
endif
" ###

if exists('&omnifunc')
  setlocal omnifunc=phpcomplete#CompletePHP
endif

" Section jumping: [[ and ]] provided by Antony Scriven <adscriven at gmail dot com>
let s:function = '\(abstract\s\+\|final\s\+\|private\s\+\|protected\s\+\|public\s\+\|static\s\+\)*function'
let s:class = '\(abstract\s\+\|final\s\+\)*class'
let s:interface = 'interface'
let s:section = '\(.*\%#\)\@!\_^\s*\zs\('.s:function.'\|'.s:class.'\|'.s:interface.'\)'
exe 'nno <buffer> <silent> [[ ?' . escape(s:section, '|') . '?<CR>:nohls<CR>'
exe 'nno <buffer> <silent> ]] /' . escape(s:section, '|') . '/<CR>:nohls<CR>'
exe 'ono <buffer> <silent> [[ ?' . escape(s:section, '|') . '?<CR>:nohls<CR>'
exe 'ono <buffer> <silent> ]] /' . escape(s:section, '|') . '/<CR>:nohls<CR>'

setlocal suffixesadd=.php
setlocal commentstring=/*%s*/

" Undo the stuff we changed.
let b:undo_ftplugin = "setlocal suffixesadd< commentstring< include< omnifunc<" .
	    \	      " | unlet! b:browsefilter b:match_words | " .
	    \	      s:undo_ftplugin

" Restore the saved compatibility options.
let &cpo = s:keepcpo
unlet s:keepcpo
