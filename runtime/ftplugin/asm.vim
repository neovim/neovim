" Vim filetype plugin file
" Language:	asm
" Maintainer:	Colin Caine <cmcaine at the common googlemail domain>
" Last Change:	2020 May 23
" 		2023 Aug 28 by Vim Project (undo_ftplugin)
" 		2024 Apr 09 by Vim Project (add Matchit support)
" 		2024 May 23 by Riley Bruins <ribru17@gmail.com> ('commentstring')

if exists("b:did_ftplugin") | finish | endif
let b:did_ftplugin = 1

setl include=^\\s*%\\s*include
setl comments=:;,s1:/*,mb:*,ex:*/,://
setl commentstring=;\ %s

let b:undo_ftplugin = "setl commentstring< comments< include<"

" Matchit support
if !exists('b:match_words')
  let b:match_skip = 's:comment\|string\|character\|special'
  let b:match_words = '^\s*%\s*if\%(\|num\|idn\|nidn\)\>:^\s*%\s*elif\>:^\s*%\s*else\>:^\s*%\s*endif\>,^\s*%\s*macro\>:^\s*%\s*endmacro\>,^\s*%\s*rep\>:^\s*%\s*endrep\>'
  let b:match_ignorecase = 1
  let b:undo_ftplugin ..= " | unlet! b:match_ignorecase b:match_words b:match_skip"
endif
