" Vim indent file
" Language:	Eiffel
" Maintainer:	Jocelyn Fiat <jfiat@eiffel.com>
" Previous-Maintainer:	David Clarke <gadicath@dishevelled.net>
" Contributions from: Thilo Six
" $Date: 2004/12/09 21:33:52 $
" $Revision: 1.3 $
" URL: https://github.com/eiffelhub/vim-eiffel

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal indentexpr=GetEiffelIndent()
setlocal nolisp
setlocal nosmartindent
setlocal nocindent
setlocal autoindent
setlocal comments=:--
setlocal indentkeys+==end,=else,=ensure,=require,=check,=loop,=until
setlocal indentkeys+==creation,=feature,=inherit,=class,=is,=redefine,=rename,=variant
setlocal indentkeys+==invariant,=do,=local,=export

let b:undo_indent = "setl smartindent< indentkeys< indentexpr< autoindent< comments< "

" Define some stuff
" keywords grouped by indenting
let s:trust_user_indent = '\(+\)\(\s*\(--\).*\)\=$'
let s:relative_indent = '^\s*\(deferred\|class\|feature\|creation\|inherit\|loop\|from\|until\|if\|else\|elseif\|ensure\|require\|check\|do\|local\|invariant\|variant\|rename\|redefine\|do\|export\)\>'
let s:outdent = '^\s*\(else\|invariant\|variant\|do\|require\|until\|loop\|local\)\>'
let s:no_indent = '^\s*\(class\|feature\|creation\|inherit\)\>'
let s:single_dent = '^[^-]\+[[:alnum:]]\+ is\(\s*\(--\).*\)\=$'
let s:inheritance_dent = '\s*\(redefine\|rename\|export\)\>'


" Only define the function once.
if exists("*GetEiffelIndent")
  finish
endif

let s:keepcpo= &cpo
set cpo&vim

function GetEiffelIndent()

  " Eiffel Class indenting
  "
  " Find a non-blank line above the current line.
  let lnum = prevnonblank(v:lnum - 1)

  " At the start of the file use zero indent.
  if lnum == 0
    return 0
  endif

  " trust the user's indenting
  if getline(lnum) =~ s:trust_user_indent
    return -1
  endif

  " Add a 'shiftwidth' after lines that start with an indent word
  let ind = indent(lnum)
  if getline(lnum) =~ s:relative_indent
    let ind = ind + &sw
  endif

  " Indent to single indent
  if getline(v:lnum) =~ s:single_dent && getline(v:lnum) !~ s:relative_indent
	   \ && getline(v:lnum) !~ '\s*\<\(and\|or\|implies\)\>'
     let ind = &sw
  endif

  " Indent to double indent
  if getline(v:lnum) =~ s:inheritance_dent
     let ind = 2 * &sw
  endif

  " Indent line after the first line of the function definition
  if getline(lnum) =~ s:single_dent
     let ind = ind + &sw
  endif

  " The following should always be at the start of a line, no indenting
  if getline(v:lnum) =~ s:no_indent
     let ind = 0
  endif

  " Subtract a 'shiftwidth', if this isn't the first thing after the 'is'
  " or first thing after the 'do'
  if getline(v:lnum) =~ s:outdent && getline(v:lnum - 1) !~ s:single_dent
	\ && getline(v:lnum - 1) !~ '^\s*do\>'
    let ind = ind - &sw
  endif

  " Subtract a shiftwidth for end statements
  if getline(v:lnum) =~ '^\s*end\>'
    let ind = ind - &sw
  endif

  " set indent of zero end statements that are at an indent of 3, this should
  " only ever be the class's end.
  if getline(v:lnum) =~ '^\s*end\>' && ind == &sw
    let ind = 0
  endif

  return ind
endfunction

let &cpo = s:keepcpo
unlet s:keepcpo

" vim:sw=2
