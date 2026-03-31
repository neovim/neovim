" Vim filetype plugin
" Language:	Forth
" Maintainer:	Johan Kotlinski <kotlinski@gmail.com>
" Last Change:	2023 Sep 15
"		2024 Jan 14 by Vim Project (browsefilter)
" URL:		https://github.com/jkotlinski/forth.vim

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

setlocal commentstring=\\\ %s
setlocal comments=s:(,mb:\ ,e:),b:\\
setlocal iskeyword=33-126,128-255

let s:include_patterns =<< trim EOL

  \<\%(INCLUDE\|REQUIRE\)\>\s\+\zs\k\+\ze
  \<S"\s\+\zs[^"]*\ze"\s\+\%(INCLUDED\|REQUIRED\)\>
EOL
let &l:include = $'\c{ s:include_patterns[1:]->join('\|') }'

let s:define_patterns =<< trim EOL
  :
  [2F]\=CONSTANT
  [2F]\=VALUE
  [2F]\=VARIABLE
  BEGIN-STRUCTURE
  BUFFER:
  CODE
  CREATE
  MARKER
  SYNONYM
EOL
let &l:define = $'\c\<\%({ s:define_patterns->join('\|') }\)'

" assume consistent intra-project file extensions
let &l:suffixesadd = "." .. expand("%:e")

let b:undo_ftplugin = "setl cms< com< def< inc< isk< sua<"

if exists("loaded_matchit") && !exists("b:match_words")
  let s:matchit_patterns =<< trim EOL

    \<\:\%(NONAME\)\=\>:\<EXIT\>:\<;\>
    \<IF\>:\<ELSE\>:\<THEN\>
    \<\[IF]\>:\<\[ELSE]\>:\<\[THEN]\>
    \<?\=DO\>:\<LEAVE\>:\<+\=LOOP\>
    \<CASE\>:\<ENDCASE\>
    \<OF\>:\<ENDOF\>
    \<BEGIN\>:\<WHILE\>:\<\%(AGAIN\|REPEAT\|UNTIL\)\>
    \<CODE\>:\<END-CODE\>
    \<BEGIN-STRUCTURE\>:\<END-STRUCTURE\>
  EOL
  let b:match_ignorecase = 1
  let b:match_words = s:matchit_patterns[1:]->join(',')
  let b:undo_ftplugin ..= "| unlet! b:match_ignorecase b:match_words"
  unlet s:matchit_patterns
endif

if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "Forth Source Files (*.f, *.fs, *.ft, *.fth, *.4th)\t*.f;*.fs;*.ft;*.fth;*.4th\n"
  if has("win32")
    let b:browsefilter ..= "All Files (*.*)\t*\n"
  else
    let b:browsefilter ..= "All Files (*)\t*\n"
  endif
  let b:undo_ftplugin ..= " | unlet! b:browsefilter"
endif

let &cpo = s:cpo_save
unlet s:cpo_save
unlet s:define_patterns s:include_patterns
