"  Maintainer:	Paulo Moura <pmoura@logtalk.org>
"  Revised on:	2018.08.04
"  Language:	Logtalk

" This Logtalk indent file is a modified version of the Prolog
" indent file written by Gergely Kontra

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
	finish
endif

let b:did_indent = 1

setlocal indentexpr=GetLogtalkIndent()
setlocal indentkeys-=:,0#
setlocal indentkeys+=0%,-,0;,>,0)

" Only define the function once.
if exists("*GetLogtalkIndent")
	finish
endif

function! GetLogtalkIndent()
	" Find a non-blank line above the current line.
	let pnum = prevnonblank(v:lnum - 1)
	" Hit the start of the file, use zero indent.
	if pnum == 0
		return 0
	endif
	let line = getline(v:lnum)
	let pline = getline(pnum)

	let ind = indent(pnum)
	" Previous line was comment -> use previous line's indent
	if pline =~ '^\s*%'
		retu ind
	endif
	" Check for entity opening directive on previous line
	if pline =~ '^\s*:-\s\(object\|protocol\|category\)\ze(.*,$'
		let ind = ind + shiftwidth()
	" Check for clause head on previous line
	elseif pline =~ ':-\s*\(%.*\)\?$'
		let ind = ind + shiftwidth()
	" Check for grammar rule head on previous line
	elseif pline =~ '-->\s*\(%.*\)\?$'
		let ind = ind + shiftwidth()
	" Check for entity closing directive on previous line
	elseif pline =~ '^\s*:-\send_\(object\|protocol\|category\)\.\(%.*\)\?$'
		let ind = ind - shiftwidth()
	" Check for end of clause on previous line
	elseif pline =~ '\.\s*\(%.*\)\?$'
		let ind = ind - shiftwidth()
	endif
	" Check for opening conditional on previous line
	if pline =~ '^\s*\([(;]\|->\)' && pline !~ '\.\s*\(%.*\)\?$' && pline !~ '^.*\([)][,]\s*\(%.*\)\?$\)'
		let ind = ind + shiftwidth()
	endif
	" Check for closing an unclosed paren, or middle ; or ->
	if line =~ '^\s*\([);]\|->\)'
		let ind = ind - shiftwidth()
	endif
	return ind
endfunction
