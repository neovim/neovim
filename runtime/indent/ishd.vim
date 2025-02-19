" Description:	InstallShield indenter
" Author:	Johannes Zellner <johannes@zellner.org>
" Last Change:	Tue, 27 Apr 2004 14:54:59 CEST

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
    finish
endif
let b:did_indent = 1

setlocal autoindent
setlocal indentexpr=GetIshdIndent(v:lnum)
setlocal indentkeys&
setlocal indentkeys+==else,=elseif,=endif,=end,=begin,<:>
" setlocal indentkeys-=0#

let b:undo_indent = "setl ai< indentexpr< indentkeys<"

" Only define the function once.
if exists("*GetIshdIndent")
    finish
endif

fun! GetIshdIndent(lnum)
    " labels and preprocessor get zero indent immediately
    let this_line = getline(a:lnum)
    let LABELS_OR_PREPROC = '^\s*\(\<\k\+\>:\s*$\|#.*\)'
    let LABELS_OR_PREPROC_EXCEPT = '^\s*\<default\+\>:'
    if this_line =~ LABELS_OR_PREPROC && this_line !~ LABELS_OR_PREPROC_EXCEPT
	return 0
    endif

    " Find a non-blank line above the current line.
    " Skip over labels and preprocessor directives.
    let lnum = a:lnum
    while lnum > 0
	let lnum = prevnonblank(lnum - 1)
	let previous_line = getline(lnum)
	if previous_line !~ LABELS_OR_PREPROC || previous_line =~ LABELS_OR_PREPROC_EXCEPT
	    break
	endif
    endwhile

    " Hit the start of the file, use zero indent.
    if lnum == 0
	return 0
    endif

    let ind = indent(lnum)

    " Add
    if previous_line =~ '^\s*\<\(function\|begin\|switch\|case\|default\|if.\{-}then\|else\|elseif\|while\|repeat\)\>'
	let ind = ind + shiftwidth()
    endif

    " Subtract
    if this_line =~ '^\s*\<endswitch\>'
	let ind = ind - 2 * shiftwidth()
    elseif this_line =~ '^\s*\<\(begin\|end\|endif\|endwhile\|else\|elseif\|until\)\>'
	let ind = ind - shiftwidth()
    elseif this_line =~ '^\s*\<\(case\|default\)\>'
	if previous_line !~ '^\s*\<switch\>'
	    let ind = ind - shiftwidth()
	endif
    endif

    return ind
endfun
