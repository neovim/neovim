" Vim indent file
" Language:	VisualBasic (ft=vb) / Basic (ft=basic) / SaxBasic (ft=vb)
" Author:	Johannes Zellner <johannes@zellner.org>
" Maintainer:	Michael Soyka (mssr953@gmail.com)
" Last Change:	Fri, 18 Jun 2004 07:22:42 CEST
"		Small update 2010 Jul 28 by Maxim Kim
"		2022/12/15: add support for multiline statements.
"		2022/12/21: move VbGetIndent from global to script-local scope
"		2022/12/26: recognize "Type" keyword

if exists("b:did_indent")
    finish
endif
let b:did_indent = 1

setlocal autoindent
setlocal indentexpr=s:VbGetIndent(v:lnum)
setlocal indentkeys&
setlocal indentkeys+==~else,=~elseif,=~end,=~wend,=~case,=~next,=~select,=~loop

let b:undo_indent = "set ai< indentexpr< indentkeys<"

" Only define the function once.
if exists("*s:VbGetIndent")
    finish
endif

function s:VbGetIndent(lnum)
    let this_lnum = a:lnum
    let this_line = getline(this_lnum)

    " labels and preprocessor get zero indent immediately
    let LABELS_OR_PREPROC = '^\s*\(\<\k\+\>:\s*$\|#.*\)'
    if this_line =~? LABELS_OR_PREPROC
	return 0
    endif
    
    " Get the current value of "shiftwidth"
    let bShiftwidth = shiftwidth()

    " Find a non-blank line above the current line.
    " Skip over labels and preprocessor directives.
    let lnum = this_lnum
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

    " Variable "previous_line" now contains the text in buffer line "lnum".

    " Multi-line statements have the underscore character at end-of-line:
    "
    "    object.method(arguments, _
    "                  arguments, _
    "                  arguments)
    "
    " and require extra logic to determine the correct indentation.
    "
    " Case 1: Line "lnum" is the first line of a multiline statement.
    "         Line "lnum" will have a trailing underscore character
    "         but the preceding non-blank line does not.
    "         Line "this_lnum" will be indented relative to "lnum".
    "
    " Case 2: Line "lnum" is the last line of a multiline statement.
    "         Line "lnum" will not have a trailing underscore character
    "         but the preceding non-blank line will.
    "         Line "this_lnum" will have the same indentation as the starting
    "         line of the multiline statement.
    "
    " Case 3: Line "lnum" is neither the first nor last line.  
    "         Lines "lnum" and "lnum-1" will have a trailing underscore
    "         character.
    "         Line "this_lnum" will have the same indentation as the preceding
    "         line.
    "
    " No matter which case it is, the starting line of the statement must be
    " found.  It will be assumed that multiline statements cannot have
    " intermingled comments, statement labels, preprocessor directives or
    " blank lines.
    "
    let lnum_is_continued = (previous_line =~ '_$')
    if lnum > 1
	let before_lnum = prevnonblank(lnum-1)
	let before_previous_line = getline(before_lnum)
    else
	let before_lnum = 0
	let before_previous_line = ""
    endif

    if before_previous_line !~ '_$'
	" Variable "previous_line" contains the start of a statement.
	"
	let ind = indent(lnum)
	if lnum_is_continued
	    let ind += bShiftwidth
	endif
    elseif ! lnum_is_continued
	" Line "lnum" contains the last line of a multiline statement.
        " Need to find where this multiline statement begins
	"
	while before_lnum > 0
	    let before_lnum -= 1
	    if getline(before_lnum) !~ '_$'
		let before_lnum += 1
		break
	    endif
	endwhile
	if before_lnum == 0
	    let before_lnum = 1
	endif
	let previous_line = getline(before_lnum)
	let ind = indent(before_lnum)
    else
	" Line "lnum" is not the first or last line of a multiline statement.
	"
	let ind = indent(lnum)
    endif

    " Add
    if previous_line =~? '^\s*\<\(begin\|\%(\%(private\|public\|friend\)\s\+\)\=\%(function\|sub\|property\|enum\|type\)\|select\|case\|default\|if\|else\|elseif\|do\|for\|while\|with\)\>'
	let ind = ind + bShiftwidth
    endif

    " Subtract
    if this_line =~? '^\s*\<end\>\s\+\<select\>'
	if previous_line !~? '^\s*\<select\>'
	    let ind = ind - 2 * bShiftwidth
	else
	    " this case is for an empty 'select' -- 'end select'
	    " (w/o any case statements) like:
	    "
	    " select case readwrite
	    " end select
	    let ind = ind - bShiftwidth
	endif
    elseif this_line =~? '^\s*\<\(end\|else\|elseif\|until\|loop\|next\|wend\)\>'
	let ind = ind - bShiftwidth
    elseif this_line =~? '^\s*\<\(case\|default\)\>'
	if previous_line !~? '^\s*\<select\>'
	    let ind = ind - bShiftwidth
	endif
    endif

    return ind
endfunction

" vim:sw=4
