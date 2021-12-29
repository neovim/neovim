"  vim: set sw=4 sts=4:
"  Language:	Prolog
"  Maintainer:	Gergely Kontra <kgergely@mcl.hu> (Invalid email address)
" 		Doug Kearns <dougkearns@gmail.com>
"  Revised on:	2002.02.18. 23:34:05
"  Last change by: Takuya Fujiwara, 2018 Sep 23

" TODO:
"   checking with respect to syntax highlighting
"   ignoring multiline comments
"   detecting multiline strings

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
    finish
endif

let b:did_indent = 1

setlocal indentexpr=GetPrologIndent()
setlocal indentkeys-=:,0#
setlocal indentkeys+=0%,-,0;,>,0)

" Only define the function once.
"if exists("*GetPrologIndent")
"    finish
"endif

function! GetPrologIndent()
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
	return ind
    endif
    " Previous line was the start of block comment -> +1 after '/*' comment
    if pline =~ '^\s*/\*'
	return ind + 1
    endif
    " Previous line was the end of block comment -> -1 after '*/' comment
    if pline =~ '^\s*\*/'
	return ind - 1
    endif
    " Check for clause head on previous line
    if pline =~ '\%(:-\|-->\)\s*\(%.*\)\?$'
	let ind = ind + shiftwidth()
    " Check for end of clause on previous line
    elseif pline =~ '\.\s*\(%.*\)\?$'
	let ind = ind - shiftwidth()
    endif
    " Check for opening conditional on previous line
    if pline =~ '^\s*\([(;]\|->\)'
	let ind = ind + shiftwidth()
    endif
    " Check for closing an unclosed paren, or middle ; or ->
    if line =~ '^\s*\([);]\|->\)'
	let ind = ind - shiftwidth()
    endif
    return ind
endfunction
