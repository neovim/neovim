" Vim filetype plugin file
" Language:		PHP
" Maintainer:		Doug Kearns <dougkearns@gmail.com>
" Previous Maintainer:	Dan Sharp
" Last Changed:		2022 Jul 20

if exists("b:did_ftplugin")
  finish
endif

" Make sure the continuation lines below do not cause problems in
" compatibility mode.
let s:keepcpo= &cpo
set cpo&vim

" Define some defaults in case the included ftplugins don't set them.
let s:undo_ftplugin = ""
let s:browsefilter = "HTML Files (*.html, *.htm)\t*.html;*.htm\n" ..
      \		     "All Files (*.*)\t*.*\n"
let s:match_words = ""

runtime! ftplugin/html.vim ftplugin/html_*.vim ftplugin/html/*.vim
let b:did_ftplugin = 1

" Override our defaults if these were set by an included ftplugin.
if exists("b:undo_ftplugin")
" let b:undo_ftplugin = "setlocal comments< commentstring< formatoptions< omnifunc<"
  let s:undo_ftplugin = b:undo_ftplugin
endif
if exists("b:browsefilter")
" let b:undo_ftplugin ..= " | unlet! b:browsefilter b:html_set_browsefilter"
  let s:browsefilter = b:browsefilter
endif
if exists("b:match_words")
" let b:undo_ftplugin ..= " | unlet! b:match_ignorecase b:match_words b:html_set_match_words"
  let s:match_words = b:match_words
endif
if exists("b:match_skip")
  unlet b:match_skip
endif

setlocal comments=s1:/*,mb:*,ex:*/,://,:#
setlocal commentstring=/*%s*/
setlocal formatoptions+=l formatoptions-=t

if get(g:, "php_autocomment", 1)
  setlocal formatoptions+=croq
  " NOTE: set g:PHP_autoformatcomment = 0 to prevent the indent plugin from
  "       overriding this 'comments' value 
  setlocal comments-=:#
  " space after # comments to exclude attributes
  setlocal comments+=b:#
endif

if exists('&omnifunc')
  setlocal omnifunc=phpcomplete#CompletePHP
endif

setlocal suffixesadd=.php

" ###
" Provided by Mikolaj Machowski <mikmach at wp dot pl>
setlocal include=\\\(require\\\|include\\\)\\\(_once\\\)\\\?
" Disabled changing 'iskeyword', it breaks a command such as "*"
" setlocal iskeyword+=$

let b:undo_ftplugin = "setlocal include< suffixesadd<"

if exists("loaded_matchit") && exists("b:html_set_match_words")
  let b:match_ignorecase = 1
  let b:match_words = 'PhpMatchWords()'

  if !exists("*PhpMatchWords")
    function! PhpMatchWords()
      " The PHP syntax file uses the Delimiter syntax group for the phpRegion
      " matchgroups, without a "php" prefix, so use the stack to test for the
      " outer phpRegion group.	This also means the closing ?> tag which is
      " outside of the matched region just uses the Delimiter group for the
      " end match.
      let stack = synstack(line('.'), col('.'))
      let php_region = !empty(stack) && synIDattr(stack[0], "name") =~# '\<php'
      if php_region || getline(".") =~ '.\=\%.c\&?>'
	let b:match_skip = "PhpMatchSkip('html')"
	return '<?php\|<?=\=:?>,' ..
	   \   '\<if\>:\<elseif\>:\<else\>:\<endif\>,' ..
	   \   '\<switch\>:\<case\>:\<break\>:\<continue\>:\<endswitch\>,' ..
	   \   '\<while\>.\{-})\s*\::\<break\>:\<continue\>:\<endwhile\>,' ..
	   \   '\<do\>:\<break\>:\<continue\>:\<while\>,' ..
	   \   '\<for\>:\<break\>:\<continue\>:\<endfor\>,' ..
	   \   '\<foreach\>:\<break\>:\<continue\>:\<endforeach\>,' ..
	   \   '\%(<<<\s*\)\@<=''\=\(\h\w*\)''\=:^\s*\1\>'

	   " TODO: these probably aren't worth adding and really need syntax support
	   "   '<\_s*script\_s*language\_s*=\_s*[''"]\=\_s*php\_s*[''"]\=\_s*>:<\_s*\_s*/\_s*script\_s*>,' ..
	   "   '<%:%>,' ..
      else
	let b:match_skip = "PhpMatchSkip('php')"
	return s:match_words
      endif
    endfunction
  endif
  if !exists("*PhpMatchSkip")
    function! PhpMatchSkip(skip)
      let name = synIDattr(synID(line('.'), col('.'), 1), 'name')
      if a:skip == "html"
	" ?> in line comments will also be correctly matched as Delimiter
	return name =~? 'comment\|string' || name !~? 'php\|delimiter'
      else " php
	return name =~? 'comment\|string\|php'
      endif
    endfunction
  endif
  let b:undo_ftplugin ..= " | unlet! b:match_skip"
endif
" ###

" Change the :browse e filter to primarily show PHP-related files.
if (has("gui_win32") || has("gui_gtk")) && exists("b:html_set_browsefilter")
  let b:browsefilter = "PHP Files (*.php)\t*.php\n" ..
	\	       "PHP Test Files (*.phpt)\t*.phpt\n" ..
	\	       s:browsefilter
endif

if !exists("no_plugin_maps") && !exists("no_php_maps")
  " Section jumping: [[ and ]] provided by Antony Scriven <adscriven at gmail dot com>
  let s:function = '\%(abstract\s\+\|final\s\+\|private\s\+\|protected\s\+\|public\s\+\|static\s\+\)*function'
  let s:class = '\%(abstract\s\+\|final\s\+\)*class'
  let s:section = escape('^\s*\zs\%(' .. s:function .. '\|' .. s:class .. '\|interface\|trait\|enum\)\>', "|")

  function! s:Jump(pattern, count, flags)
    normal! m'
    for i in range(a:count)
      if !search(a:pattern, a:flags)
	break
      endif
    endfor
  endfunction

  for mode in ["n", "o", "x"]
    exe mode .. "noremap <buffer> <silent> ]] <Cmd>call <SID>Jump('" .. s:section .. "', v:count1, 'W')<CR>"
    exe mode .. "noremap <buffer> <silent> [[ <Cmd>call <SID>Jump('" .. s:section .. "', v:count1, 'bW')<CR>"
    let b:undo_ftplugin ..= " | sil! exe '" .. mode .. "unmap <buffer> ]]'" ..
	  \		    " | sil! exe '" .. mode .. "unmap <buffer> [['"
  endfor
endif

let b:undo_ftplugin ..= " | " .. s:undo_ftplugin

" Restore the saved compatibility options.
let &cpo = s:keepcpo
unlet s:keepcpo

" vim: nowrap sw=2 sts=2 ts=8 noet:
