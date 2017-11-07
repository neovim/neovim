" Vim indent file
" Program:      CMake - Cross-Platform Makefile Generator
" Module:       $RCSfile: cmake-indent.vim,v $
" Language:     CMake (ft=cmake)
" Author:       Andy Cedilnik <andy.cedilnik@kitware.com>
" Maintainer:   Karthik Krishnan <karthik.krishnan@kitware.com>
" Last Change:  $Date: 2008-01-16 16:53:53 $
" Version:      $Revision: 1.9 $
"
" Licence:      The CMake license applies to this file. See
"               http://www.cmake.org/HTML/Copyright.html
"               This implies that distribution with Vim is allowed

if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal indentexpr=CMakeGetIndent(v:lnum)
setlocal indentkeys+==ENDIF(,ENDFOREACH(,ENDMACRO(,ELSE(,ELSEIF(,ENDWHILE(

" Only define the function once.
if exists("*CMakeGetIndent")
  finish
endif
let s:keepcpo= &cpo
set cpo&vim

fun! CMakeGetIndent(lnum)
  let this_line = getline(a:lnum)

  " Find a non-blank line above the current line.
  let lnum = a:lnum
  let lnum = prevnonblank(lnum - 1)
  let previous_line = getline(lnum)

  " Hit the start of the file, use zero indent.
  if lnum == 0
    return 0
  endif

  let ind = indent(lnum)

  let or = '\|'
  " Regular expressions used by line indentation function.
  let cmake_regex_comment = '#.*'
  let cmake_regex_identifier = '[A-Za-z][A-Za-z0-9_]*'
  let cmake_regex_quoted = '"\([^"\\]\|\\.\)*"'
  let cmake_regex_arguments = '\(' . cmake_regex_quoted .
                    \       or . '\$(' . cmake_regex_identifier . ')' .
                    \       or . '[^()\\#"]' . or . '\\.' . '\)*'

  let cmake_indent_comment_line = '^\s*' . cmake_regex_comment
  let cmake_indent_blank_regex = '^\s*$'
  let cmake_indent_open_regex = '^\s*' . cmake_regex_identifier .
                    \           '\s*(' . cmake_regex_arguments .
                    \           '\(' . cmake_regex_comment . '\)\?$'

  let cmake_indent_close_regex = '^' . cmake_regex_arguments .
                    \            ')\s*' .
                    \            '\(' . cmake_regex_comment . '\)\?$'

  let cmake_indent_begin_regex = '^\s*\(IF\|MACRO\|FOREACH\|ELSE\|ELSEIF\|WHILE\|FUNCTION\)\s*('
  let cmake_indent_end_regex = '^\s*\(ENDIF\|ENDFOREACH\|ENDMACRO\|ELSE\|ELSEIF\|ENDWHILE\|ENDFUNCTION\)\s*('

  " Add
  if previous_line =~? cmake_indent_comment_line " Handle comments
    let ind = ind
  else
    if previous_line =~? cmake_indent_begin_regex
      let ind = ind + shiftwidth()
    endif
    if previous_line =~? cmake_indent_open_regex
      let ind = ind + shiftwidth()
    endif
  endif

  " Subtract
  if this_line =~? cmake_indent_end_regex
    let ind = ind - shiftwidth()
  endif
  if previous_line =~? cmake_indent_close_regex
    let ind = ind - shiftwidth()
  endif

  return ind
endfun

let &cpo = s:keepcpo
unlet s:keepcpo
