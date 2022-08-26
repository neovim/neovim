" Vim filetype plugin file
" Language:	TypeScript React
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2020 Aug 09

let s:match_words = ""
let s:undo_ftplugin = ""

runtime! ftplugin/typescript.vim

let s:cpo_save = &cpo
set cpo-=C

if exists("b:match_words")
    let s:match_words = b:match_words
endif
if exists("b:undo_ftplugin")
    let s:undo_ftplugin = b:undo_ftplugin
endif

" Matchit configuration
if exists("loaded_matchit")
    let b:match_ignorecase = 0
    let b:match_words = s:match_words .
		\	'<:>,' .
		\	'<\@<=\([^ \t>/]\+\)\%(\s\+[^>]*\%([^/]>\|$\)\|>\|$\):<\@<=/\1>,' .
		\	'<\@<=\%([^ \t>/]\+\)\%(\s\+[^/>]*\|$\):/>'
endif

let b:undo_ftplugin = "unlet! b:match_words b:match_ignorecase | " . s:undo_ftplugin

let &cpo = s:cpo_save
unlet s:cpo_save
