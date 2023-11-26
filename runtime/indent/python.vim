" Vim indent file
" Language:	Python
" Maintainer:	The Vim Project <https://github.com/vim/vim>
" Last Change:	2023 Aug 10
" Former Maintainer:	Bram Moolenaar <Bram@vim.org>
" Original Author:	David Bustos <bustos@caltech.edu>

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

" Some preliminary settings
setlocal nolisp		" Make sure lisp indenting doesn't supersede us
setlocal autoindent	" indentexpr isn't much help otherwise

setlocal indentexpr=python#GetIndent(v:lnum)
setlocal indentkeys+=<:>,=elif,=except

let b:undo_indent = "setl ai< inde< indk< lisp<"

" Only define the function once.
if exists("*GetPythonIndent")
  finish
endif

" Keep this for backward compatibility, new scripts should use
" python#GetIndent()
function GetPythonIndent(lnum)
  return python#GetIndent(a:lnum)
endfunction

" vim:sw=2
