" Vim syntax support file
" Maintainer:	The Vim Project <https://github.com/vim/vim>
" Last Change:	2023 Aug 10
" Former Maintainer:	Bram Moolenaar <Bram@vim.org>

" This file sets up for syntax highlighting.
" It is loaded from "syntax.vim" and "manual.vim".
" 1. Set the default highlight groups.
" 2. Install Syntax autocommands for all the available syntax files.

if !has("syntax")
  finish
endif

" let others know that syntax has been switched on
let syntax_on = 1

" Line continuation is used here, remove 'C' from 'cpoptions'
let s:cpo_save = &cpo
set cpo&vim

" First remove all old syntax autocommands.
au! Syntax

au Syntax *		call s:SynSet()

fun! s:SynSet()
  " clear syntax for :set syntax=OFF  and any syntax name that doesn't exist
  syn clear
  if exists("b:current_syntax")
    unlet b:current_syntax
  endif

  0verbose let s = expand("<amatch>")
  if s == "ON"
    " :set syntax=ON
    if &filetype == ""
      echohl ErrorMsg
      echo "filetype unknown"
      echohl None
    endif
    let s = &filetype
  elseif s == "OFF"
    let s = ""
  endif

  if s != ""
    " Load the syntax file(s).  When there are several, separated by dots,
    " load each in sequence.  Skip empty entries.
    for name in split(s, '\.')
      if !empty(name)
        " XXX: "[.]" in the first pattern makes it a wildcard on Windows
        exe $'runtime! syntax/{name}[.]{{vim,lua}} syntax/{name}/*.{{vim,lua}}'
      endif
    endfor
  endif
endfun


" Handle adding doxygen to other languages (C, C++, C#, IDL, java, php, DataScript)
au Syntax c,cpp,cs,idl,java,php,datascript
	\ if (exists('b:load_doxygen_syntax') && b:load_doxygen_syntax)
	\	|| (exists('g:load_doxygen_syntax') && g:load_doxygen_syntax)
	\   | runtime! syntax/doxygen.vim
	\ | endif


" Source the user-specified syntax highlighting file
if exists("mysyntaxfile")
  let s:fname = expand(mysyntaxfile)
  if filereadable(s:fname)
    execute "source " . fnameescape(s:fname)
  endif
endif

" Restore 'cpoptions'
let &cpo = s:cpo_save
unlet s:cpo_save
