" Vim indent file
" Language:	Fortran 2008 (and older: Fortran 2003, 95, 90, and 77)
" Version:	(v48) 2020 October 07
" Maintainer:	Ajit J. Thakkar <ajit@unb.ca>; <http://www2.unb.ca/~ajit/>
" Usage:	For instructions, do :help fortran-indent from Vim
" Credits:
"  Version 0.1 was created in September 2000 by Ajit Thakkar.
"  Since then, useful suggestions and contributions have been made, in order, by:
"  Albert Oliver Serra, Takuya Fujiwara, Philipp Edelmann, Eisuke Kawashima,
"  and Louis Cochen.

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

let s:cposet=&cpoptions
set cpoptions&vim

setlocal indentkeys+==~end,=~case,=~if,=~else,=~do,=~where,=~elsewhere,=~select
setlocal indentkeys+==~endif,=~enddo,=~endwhere,=~endselect,=~elseif
setlocal indentkeys+==~type,=~interface,=~forall,=~associate,=~block,=~enum
setlocal indentkeys+==~endforall,=~endassociate,=~endblock,=~endenum
if exists("b:fortran_indent_more") || exists("g:fortran_indent_more")
  setlocal indentkeys+==~function,=~subroutine,=~module,=~contains,=~program
  setlocal indentkeys+==~endfunction,=~endsubroutine,=~endmodule
  setlocal indentkeys+==~endprogram
endif

" Determine whether this is a fixed or free format source file
" if this hasn't been done yet using the priority:
" buffer-local value
" > global value
" > file extension as in Intel ifort, gcc (gfortran), NAG, Pathscale, and Cray compilers
if !exists("b:fortran_fixed_source")
  if exists("fortran_free_source")
    " User guarantees free source form
    let b:fortran_fixed_source = 0
  elseif exists("fortran_fixed_source")
    " User guarantees fixed source form
    let b:fortran_fixed_source = 1
  elseif expand("%:e") =~? '^f\%(90\|95\|03\|08\)$'
    " Free-form file extension defaults as in Intel ifort, gcc(gfortran), NAG, Pathscale, and Cray compilers
    let b:fortran_fixed_source = 0
  elseif expand("%:e") =~? '^\%(f\|f77\|for\)$'
    " Fixed-form file extension defaults
    let b:fortran_fixed_source = 1
  else
    " Modern fortran still allows both fixed and free source form
    " Assume fixed source form unless signs of free source form
    " are detected in the first five columns of the first s:lmax lines.
    " Detection becomes more accurate and time-consuming if more lines
    " are checked. Increase the limit below if you keep lots of comments at
    " the very top of each file and you have a fast computer.
    let s:lmax = 500
    if ( s:lmax > line("$") )
      let s:lmax = line("$")
    endif
    let b:fortran_fixed_source = 1
    let s:ln=1
    while s:ln <= s:lmax
      let s:test = strpart(getline(s:ln),0,5)
      if s:test !~ '^[Cc*]' && s:test !~ '^ *[!#]' && s:test =~ '[^ 0-9\t]' && s:test !~ '^[ 0-9]*\t'
	let b:fortran_fixed_source = 0
	break
      endif
      let s:ln = s:ln + 1
    endwhile
  endif
endif

" Define the appropriate indent function but only once
if (b:fortran_fixed_source == 1)
  setlocal indentexpr=FortranGetFixedIndent()
  if exists("*FortranGetFixedIndent")
    finish
  endif
else
  setlocal indentexpr=FortranGetFreeIndent()
  if exists("*FortranGetFreeIndent")
    finish
  endif
endif

function FortranGetIndent(lnum)
  let ind = indent(a:lnum)
  let prevline=getline(a:lnum)
  " Strip tail comment
  let prevstat=substitute(prevline, '!.*$', '', '')
  let prev2line=getline(a:lnum-1)
  let prev2stat=substitute(prev2line, '!.*$', '', '')

  "Indent do loops only if they are all guaranteed to be of do/end do type
  if exists("b:fortran_do_enddo") || exists("g:fortran_do_enddo")
    if prevstat =~? '^\s*\(\d\+\s\)\=\s*\(\a\w*\s*:\)\=\s*do\>'
      let ind = ind + shiftwidth()
    endif
    if getline(v:lnum) =~? '^\s*\(\d\+\s\)\=\s*end\s*do\>'
      let ind = ind - shiftwidth()
    endif
  endif

  "Add a shiftwidth to statements following if, else, else if, case, class,
  "where, else where, forall, type, interface and associate statements
  if prevstat =~? '^\s*\(case\|class\|else\|else\s*if\|else\s*where\)\>'
	\ ||prevstat=~? '^\s*\(type\|interface\|associate\|enum\)\>'
	\ ||prevstat=~?'^\s*\(\d\+\s\)\=\s*\(\a\w*\s*:\)\=\s*\(forall\|where\|block\)\>'
	\ ||prevstat=~? '^\s*\(\d\+\s\)\=\s*\(\a\w*\s*:\)\=\s*if\>'
     let ind = ind + shiftwidth()
    " Remove unwanted indent after logical and arithmetic ifs
    if prevstat =~? '\<if\>' && prevstat !~? '\<then\>'
      let ind = ind - shiftwidth()
    endif
    " Remove unwanted indent after type( statements
    if prevstat =~? '^\s*type\s*('
      let ind = ind - shiftwidth()
    endif
  endif

  "Indent program units unless instructed otherwise
  if !exists("b:fortran_indent_less") && !exists("g:fortran_indent_less")
    let prefix='\(\(pure\|impure\|elemental\|recursive\)\s\+\)\{,2}'
    let type='\(\(integer\|real\|double\s\+precision\|complex\|logical'
          \.'\|character\|type\|class\)\s*\S*\s\+\)\='
    if prevstat =~? '^\s*\(contains\|submodule\|program\)\>'
            \ ||prevstat =~? '^\s*'.'module\>\(\s*\procedure\)\@!'
            \ ||prevstat =~? '^\s*'.prefix.'subroutine\>'
            \ ||prevstat =~? '^\s*'.prefix.type.'function\>'
            \ ||prevstat =~? '^\s*'.type.prefix.'function\>'
      let ind = ind + shiftwidth()
    endif
    if getline(v:lnum) =~? '^\s*contains\>'
          \ ||getline(v:lnum)=~? '^\s*end\s*'
          \ .'\(function\|subroutine\|module\|submodule\|program\)\>'
      let ind = ind - shiftwidth()
    endif
  endif

  "Subtract a shiftwidth from else, else if, elsewhere, case, class, end if,
  " end where, end select, end forall, end interface, end associate,
  " end enum, end type, end block and end type statements
  if getline(v:lnum) =~? '^\s*\(\d\+\s\)\=\s*'
        \. '\(else\|else\s*if\|else\s*where\|case\|class\|'
        \. 'end\s*\(if\|where\|select\|interface\|'
        \. 'type\|forall\|associate\|enum\|block\)\)\>'
    let ind = ind - shiftwidth()
    " Fix indent for case statement immediately after select
    if prevstat =~? '\<select\s*\(case\|type\)\>'
      let ind = ind + shiftwidth()
    endif
  endif

  "First continuation line
  if prevstat =~ '&\s*$' && prev2stat !~ '&\s*$'
    let ind = ind + shiftwidth()
  endif
  "Line after last continuation line
  if prevstat !~ '&\s*$' && prev2stat =~ '&\s*$' && prevstat !~? '\<then\>'
    let ind = ind - shiftwidth()
  endif

  return ind
endfunction

function FortranGetFreeIndent()
  "Find the previous non-blank line
  let lnum = prevnonblank(v:lnum - 1)

  "Use zero indent at the top of the file
  if lnum == 0
    return 0
  endif

  let ind=FortranGetIndent(lnum)
  return ind
endfunction

function FortranGetFixedIndent()
  let currline=getline(v:lnum)
  "Don't indent comments, continuation lines and labelled lines
  if strpart(currline,0,6) =~ '[^ \t]'
    let ind = indent(v:lnum)
    return ind
  endif

  "Find the previous line which is not blank, not a comment,
  "not a continuation line, and does not have a label
  let lnum = v:lnum - 1
  while lnum > 0
    let prevline=getline(lnum)
    if (prevline =~ "^[C*!]") || (prevline =~ "^\s*$")
	\ || (strpart(prevline,5,1) !~ "[ 0]")
      " Skip comments, blank lines and continuation lines
      let lnum = lnum - 1
    else
      let test=strpart(prevline,0,5)
      if test =~ "[0-9]"
	" Skip lines with statement numbers
	let lnum = lnum - 1
      else
	break
      endif
    endif
  endwhile

  "First line must begin at column 7
  if lnum == 0
    return 6
  endif

  let ind=FortranGetIndent(lnum)
  return ind
endfunction

let &cpoptions=s:cposet
unlet s:cposet

" vim:sw=2 tw=130
