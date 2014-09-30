" Vim indent file
" Language:	VisualBasic (ft=vb) / Basic (ft=basic) / SaxBasic (ft=vb)
" Author:	Johannes Zellner <johannes@zellner.org>
" Last Change:	Fri, 18 Jun 2004 07:22:42 CEST
"		Small update 2010 Jul 28 by Maxim Kim

if exists("b:did_indent")
    finish
endif
let b:did_indent = 1

setlocal autoindent
setlocal indentexpr=VbGetIndent(v:lnum)
setlocal indentkeys&
setlocal indentkeys+==~else,=~elseif,=~end,=~wend,=~case,=~next,=~select,=~loop,<:>

let b:undo_indent = "set ai< indentexpr< indentkeys<"

" Only define the function once.
if exists("*VbGetIndent")
    finish
endif

fun! VbGetIndent(lnum)
    " labels and preprocessor get zero indent immediately
    let this_line = getline(a:lnum)
    let LABELS_OR_PREPROC = '^\s*\(\<\k\+\>:\s*$\|#.*\)'
    if this_line =~? LABELS_OR_PREPROC
	return 0
    endif

    " Find a non-blank line above the current line.
    " Skip over labels and preprocessor directives.
    let lnum = a:lnum
    while lnum > 0
	let lnum = prevnonblank(lnum - 1)
	let previous_line = getline(lnum)
	if previous_line !~? LABELS_OR_PREPROC
	    break
	endif
    endwhile

    " Hit the start of the file, use zero indent.
    if lnum == 0
	return 0
    endif

    let ind = indent(lnum)

    " Add
    if previous_line =~? '^\s*\<\(begin\|\%(\%(private\|public\|friend\)\s\+\)\=\%(function\|sub\|property\)\|select\|case\|default\|if\|else\|elseif\|do\|for\|while\|enum\|with\)\>'
	let ind = ind + &sw
    endif

    " Subtract
    if this_line =~? '^\s*\<end\>\s\+\<select\>'
	if previous_line !~? '^\s*\<select\>'
	    let ind = ind - 2 * &sw
	else
	    " this case is for an empty 'select' -- 'end select'
	    " (w/o any case statements) like:
	    "
	    " select case readwrite
	    " end select
	    let ind = ind - &sw
	endif
    elseif this_line =~? '^\s*\<\(end\|else\|elseif\|until\|loop\|next\|wend\)\>'
	let ind = ind - &sw
    elseif this_line =~? '^\s*\<\(case\|default\)\>'
	if previous_line !~? '^\s*\<select\>'
	    let ind = ind - &sw
	endif
    endif

    return ind
endfun

" vim:sw=4
