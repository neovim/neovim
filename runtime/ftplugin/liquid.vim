" Vim filetype plugin
" Language:     Liquid
" Maintainer:   Tim Pope <vimNOSPAM@tpope.org>
" Last Change:	2022 Mar 15

if exists('b:did_ftplugin')
  finish
endif

if !exists('g:liquid_default_subtype')
  let g:liquid_default_subtype = 'html'
endif

if !exists('b:liquid_subtype')
  let s:lines = getline(1)."\n".getline(2)."\n".getline(3)."\n".getline(4)."\n".getline(5)."\n".getline("$")
  let b:liquid_subtype = matchstr(s:lines,'liquid_subtype=\zs\w\+')
  if b:liquid_subtype == ''
    let b:liquid_subtype = matchstr(&filetype,'^liquid\.\zs\w\+')
  endif
  if b:liquid_subtype == ''
    let b:liquid_subtype = matchstr(substitute(expand('%:t'),'\c\%(\.liquid\)\+$','',''),'\.\zs\w\+$')
  endif
  if b:liquid_subtype == ''
    let b:liquid_subtype = g:liquid_default_subtype
  endif
endif

if exists('b:liquid_subtype') && b:liquid_subtype != ''
  exe 'runtime! ftplugin/'.b:liquid_subtype.'.vim ftplugin/'.b:liquid_subtype.'_*.vim ftplugin/'.b:liquid_subtype.'/*.vim'
else
  runtime! ftplugin/html.vim ftplugin/html_*.vim ftplugin/html/*.vim
endif
let b:did_ftplugin = 1

if exists('b:undo_ftplugin')
  let b:undo_ftplugin .= '|'
else
  let b:undo_ftplugin = ''
endif
if exists('b:browsefilter')
  let b:browsefilter = "\n".b:browsefilter
else
  let b:browsefilter = ''
endif
if exists('b:match_words')
  let b:match_words .= ','
elseif exists('loaded_matchit')
  let b:match_words = ''
endif

if has('gui_win32')
  let b:browsefilter="Liquid Files (*.liquid)\t*.liquid" . b:browsefilter
endif

if exists('loaded_matchit')
  let b:match_words .= '\<\%(if\w*\|unless\|case\)\>:\<\%(elsif\|else\|when\)\>:\<end\%(if\w*\|unless\|case\)\>,\<\%(for\|tablerow\)\>:\%({%\s*\)\@<=empty\>:\<end\%(for\|tablerow\)\>,\<\(capture\|comment\|highlight\)\>:\<end\1\>'
endif

setlocal commentstring={%\ comment\ %}%s{%\ endcomment\ %}

let b:undo_ftplugin .= 'setl cms< | unlet! b:browsefilter b:match_words'
