" Vim filetype plugin
" Language:    CMake
" Maintainer:  Keith Smiley <keithbsmiley@gmail.com>
" Last Change: 2018 Aug 30

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif

" save 'cpo' for restoration at the end of this file
let s:cpo_save = &cpo
set cpo&vim

" Don't load another plugin for this buffer
let b:did_ftplugin = 1

let b:undo_ftplugin = "setl commentstring<"

if exists('loaded_matchit')
  let b:match_words = '\<if\>:\<elseif\>\|\<else\>:\<endif\>'
        \ . ',\<foreach\>\|\<while\>:\<break\>:\<endforeach\>\|\<endwhile\>'
        \ . ',\<macro\>:\<endmacro\>'
        \ . ',\<function\>:\<endfunction\>'
  let b:match_ignorecase = 1

  let b:undo_ftplugin .= "| unlet b:match_words"
endif

setlocal commentstring=#\ %s

" restore 'cpo' and clean up buffer variable
let &cpo = s:cpo_save
unlet s:cpo_save
