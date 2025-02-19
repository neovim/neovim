" Vim filetype plugin file
" Language:	Microsoft Macro Assembler (80x86)
" Maintainer:	Wu Yongwei <wuyongwei@gmail.com>
" Last Change:	2022-04-24 21:24:52 +0800

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

let b:undo_ftplugin = "setl iskeyword<"

setlocal iskeyword=@,48-57,_,36,60,62,63,@-@

" Matchit support
if !exists('b:match_words')
  let b:match_words = '^\s*\.IF\>:^\s*\.ELSEIF\>:^\s*\.ELSE\>:^\s*\.ENDIF\>,'
        \ .. '^\s*\.REPEAT\>:^\s*\.UNTIL\(CXZ\)\?\>,'
        \ .. '^\s*\.WHILE\>:^\s*\.ENDW\>,'
        \ .. '^\s*IF\(1\|2\|E\|DEF\|NDEF\|B\|NB\|IDNI\?\|DIFI\?\)\?\>:^\s*ELSEIF\(1\|2\|E\|DEF\|NDEF\|B\|NB\|IDNI\?\|DIFI\?\)\?\>:^\s*ELSE\>:^\s*ENDIF\>,'
        \ .. '\(\<MACRO\>\|^\s*%\?\s*FORC\?\>\|^\s*REPEAT\>\|^\s*WHILE\):^\s*ENDM\>,'
        \ .. '\<PROC\>:\<ENDP\>,'
        \ .. '\<SEGMENT\>:\<ENDS\>'
  let b:match_ignorecase = 1
  let b:undo_ftplugin ..= " | unlet! b:match_ignorecase b:match_words"
endif

let &cpo = s:cpo_save
unlet s:cpo_save
