" Elm indent plugin file
" Language: Elm
" Maintainer: Andreas Scharf <as@99n.de>
" Original Author: Joseph Hager <ajhager@gmail.com>
" Copyright: Joseph Hager <ajhager@gmail.com>
" License: BSD3
" Latest Revision: 2020-05-29

" Only load this indent file when no other was loaded.
if exists('b:did_indent')
	finish
endif
let b:did_indent = 1

" Local defaults
setlocal expandtab
setlocal indentexpr=GetElmIndent()
setlocal indentkeys+=0=else,0=if,0=of,0=import,0=then,0=type,0\|,0},0\],0),=-},0=in
setlocal nolisp
setlocal nosmartindent

" Only define the function once.
if exists('*GetElmIndent')
	finish
endif

" Indent pairs
function! s:FindPair(pstart, pmid, pend)
	"call search(a:pend, 'bW')
	return indent(searchpair(a:pstart, a:pmid, a:pend, 'bWn', 'synIDattr(synID(line("."), col("."), 0), "name") =~? "string\\|comment"'))
endfunction

function! GetElmIndent()
	let l:lnum = v:lnum - 1

	" Ident 0 if the first line of the file:
	if l:lnum == 0
		return 0
	endif

	let l:ind = indent(l:lnum)
	let l:lline = getline(l:lnum)
	let l:line = getline(v:lnum)

	" Indent if current line begins with '}':
	if l:line =~? '^\s*}'
		return s:FindPair('{', '', '}')

	" Indent if current line begins with 'else':
	elseif l:line =~# '^\s*else\>'
		if l:lline !~# '^\s*\(if\|then\)\>'
			return s:FindPair('\<if\>', '', '\<else\>')
		endif

	" Indent if current line begins with 'then':
	elseif l:line =~# '^\s*then\>'
		if l:lline !~# '^\s*\(if\|else\)\>'
			return s:FindPair('\<if\>', '', '\<then\>')
		endif

	" HACK: Indent lines in case with nearest case clause:
	elseif l:line =~# '->' && l:line !~# ':' && l:line !~# '\\'
		return indent(search('^\s*case', 'bWn')) + &shiftwidth

	" HACK: Don't change the indentation if the last line is a comment.
	elseif l:lline =~# '^\s*--'
		return l:ind

	" Align the end of block comments with the start
	elseif l:line =~# '^\s*-}'
		return indent(search('{-', 'bWn'))

	" Indent double shift after let with an empty rhs
	elseif l:lline =~# '\<let\>.*\s=$'
		return l:ind + 4 + &shiftwidth

	" Align 'in' with the parent let.
	elseif l:line =~# '^\s*in\>'
		return indent(search('^\s*let', 'bWn'))

	" Align bindings with the parent let.
	elseif l:lline =~# '\<let\>'
		return l:ind + 4

	" Align bindings with the parent in.
	elseif l:lline =~# '^\s*in\>'
		return l:ind

	endif

	" Add a 'shiftwidth' after lines ending with:
	if l:lline =~# '\(|\|=\|->\|<-\|(\|\[\|{\|\<\(of\|else\|if\|then\)\)\s*$'
		let l:ind = l:ind + &shiftwidth

	" Add a 'shiftwidth' after lines starting with type ending with '=':
	elseif l:lline =~# '^\s*type' && l:line =~# '^\s*='
		let l:ind = l:ind + &shiftwidth

	" Back to normal indent after comments:
	elseif l:lline =~# '-}\s*$'
		call search('-}', 'bW')
		let l:ind = indent(searchpair('{-', '', '-}', 'bWn', 'synIDattr(synID(line("."), col("."), 0), "name") =~? "string"'))

	" Ident some operators if there aren't any starting the last line.
	elseif l:line =~# '^\s*\(!\|&\|(\|`\|+\||\|{\|[\|,\)=' && l:lline !~# '^\s*\(!\|&\|(\|`\|+\||\|{\|[\|,\)=' && l:lline !~# '^\s*$'
		let l:ind = l:ind + &shiftwidth

	elseif l:lline ==# '' && getline(l:lnum - 1) !=# ''
		let l:ind = indent(search('^\s*\S+', 'bWn'))

	endif

	return l:ind
endfunc
