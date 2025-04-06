" Vim filetype plugin
" Language:	svelte
" Maintainer:	Igor Lacerda <igorlafarsi@gmail.com>
" Last Change:	2025 Apr 06

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

let s:cpo_sav = &cpo
set cpo&vim

setlocal matchpairs+=<:>
setlocal commentstring=<!--\ %s\ -->
setlocal comments=s:<!--,m:\ \ \ \ ,e:-->

let b:undo_ftplugin = 'setlocal comments< commentstring< matchpairs<'

if exists('&omnifunc')
  setlocal omnifunc=htmlcomplete#CompleteTags
  call htmlcomplete#DetectOmniFlavor()
  let b:undo_ftplugin ..= " | setlocal omnifunc<"
endif

if exists("loaded_matchit") && !exists("b:match_words")
  let b:match_ignorecase = 1
  let b:match_words = '<:>,' .
    \ '<\@<=[ou]l\>[^>]*\%(>\|$\):<\@<=li\>:<\@<=/[ou]l>,' .
    \ '<\@<=dl\>[^>]*\%(>\|$\):<\@<=d[td]\>:<\@<=/dl>,' .
    \ '<\@<=\([^/][^ \t>]*\)[^>]*\%(>\|$\):<\@<=/\1>,' .
    \ '{#\(if\|each\)[^}]*}:{\:else[^}]*}:{\/\(if\|each\)},' .
    \ '{#await[^}]*}:{\:then[^}]*}:{\:catch[^}]*}:{\/await},' .
    \ '{#snippet[^}]*}:{\/snippet},' .
    \ '{#key[^}]*}:{\/key}'
  let b:html_set_match_words = 1
  let b:undo_ftplugin ..= " | unlet! b:match_ignorecase b:match_words b:html_set_match_words"
endif
let &cpo = s:cpo_sav
unlet! s:cpo_sav
