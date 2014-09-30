" Vim filetype plugin file
" Language:         ConTeXt typesetting engine
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2008-07-09

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

let b:undo_ftplugin = "setl com< cms< def< inc< sua< fo<"

setlocal comments=b:%D,b:%C,b:%M,:% commentstring=%\ %s formatoptions+=tcroql

let &l:define='\\\%([egx]\|char\|mathchar\|count\|dimen\|muskip\|skip\|toks\)\='
        \ .     'def\|\\font\|\\\%(future\)\=let'
        \ . '\|\\new\%(count\|dimen\|skip\|muskip\|box\|toks\|read\|write'
        \ .     '\|fam\|insert\|if\)'

let &l:include = '^\s*\%(input\|component\)'

setlocal suffixesadd=.tex

if exists("loaded_matchit")
  let b:match_ignorecase = 0
  let b:match_skip = 'r:\\\@<!\%(\\\\\)*%'
  let b:match_words = '(:),\[:],{:},\\(:\\),\\\[:\\],' .
        \ '\\start\(\a\+\):\\stop\1'
endif

let &cpo = s:cpo_save
unlet s:cpo_save
