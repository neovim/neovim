" Vim indent file
" Language:    Pascal
" Maintainer:  Neil Carter <n.carter@swansea.ac.uk>
" Created:     2004 Jul 13
" Last Change: 2021 Sep 22
"
" For further documentation, see https://psy.swansea.ac.uk/staff/carter/vim/


if exists("b:did_indent")
	finish
endif
let b:did_indent = 1

setlocal indentexpr=GetPascalIndent(v:lnum)
setlocal indentkeys&
setlocal indentkeys+==end;,==const,==type,==var,==begin,==repeat,==until,==for
setlocal indentkeys+==program,==function,==procedure,==object,==private
setlocal indentkeys+==record,==if,==else,==case

let b:undo_indent = 'setlocal indentexpr< indentkeys<'

if exists("*GetPascalIndent")
	finish
endif


" ________________________________________________________________
function! s:GetPrevNonCommentLineNum( line_num )

	" Skip lines starting with a comment
	let SKIP_LINES = '^\s*\(\((\*\)\|\(\*\ \)\|\(\*)\)\|{\|}\)'

	let nline = a:line_num
	while nline > 0
		let nline = prevnonblank(nline-1)
		if getline(nline) !~? SKIP_LINES
			break
		endif
	endwhile

	return nline
endfunction


" ________________________________________________________________
function! s:PurifyCode( line_num )
	" Strip any trailing comments and whitespace
	let pureline = 'TODO'
	return pureline
endfunction


" ________________________________________________________________
function! GetPascalIndent( line_num )

	" Line 0 always goes at column 0
	if a:line_num == 0
		return 0
	endif

	let this_codeline = getline( a:line_num )


	" SAME INDENT

	" Middle of a three-part comment
	if this_codeline =~ '^\s*\*'
		return indent( a:line_num - 1)
	endif


	" COLUMN 1 ALWAYS

	" Last line of the program
	if this_codeline =~ '^\s*end\.'
		return 0
	endif

	" Compiler directives, allowing "(*" and "{"
	"if this_codeline =~ '^\s*\({\|(\*\)$\(IFDEF\|IFNDEF\|ELSE\|ENDIF\)'
	if this_codeline =~ '^\s*\({\|(\*\)\$'
		return 0
	endif

	" section headers
	if this_codeline =~ '^\s*\(program\|procedure\|function\|type\)\>'
		return 0
	endif

	" Subroutine separators, lines ending with "const" or "var"
	if this_codeline =~ '^\s*\((\*\ _\+\ \*)\|\(const\|var\)\)$'
		return 0
	endif


	" OTHERWISE, WE NEED TO LOOK FURTHER BACK...

	let prev_codeline_num = s:GetPrevNonCommentLineNum( a:line_num )
	let prev_codeline = getline( prev_codeline_num )
	let indnt = indent( prev_codeline_num )


	" INCREASE INDENT

	" If the PREVIOUS LINE ended in these items, always indent
	if prev_codeline =~ '\<\(type\|const\|var\)$'
		return indnt + shiftwidth()
	endif

	if prev_codeline =~ '\<repeat$'
		if this_codeline !~ '^\s*until\>'
			return indnt + shiftwidth()
		else
			return indnt
		endif
	endif

	if prev_codeline =~ '\<\(begin\|record\)$'
		if this_codeline !~ '^\s*end\>'
			return indnt + shiftwidth()
		else
			return indnt
		endif
	endif

	" If the PREVIOUS LINE ended with these items, indent if not
	" followed by "begin"
	if prev_codeline =~ '\<\(\|else\|then\|do\)$' || prev_codeline =~ ':$'
		if this_codeline !~ '^\s*begin\>'
			return indnt + shiftwidth()
		else
			" If it does start with "begin" then keep the same indent
			"return indnt + shiftwidth()
			return indnt
		endif
	endif

	" Inside a parameter list (i.e. a "(" without a ")"). ???? Considers
	" only the line before the current one. TODO: Get it working for
	" parameter lists longer than two lines.
	if prev_codeline =~ '([^)]\+$'
		return indnt + shiftwidth()
	endif


	" DECREASE INDENT

	" Lines starting with "else", but not following line ending with
	" "end".
	if this_codeline =~ '^\s*else\>' && prev_codeline !~ '\<end$'
		return indnt - shiftwidth()
	endif

	" Lines after a single-statement branch/loop.
	" Two lines before ended in "then", "else", or "do"
	" Previous line didn't end in "begin"
	let prev2_codeline_num = s:GetPrevNonCommentLineNum( prev_codeline_num )
	let prev2_codeline = getline( prev2_codeline_num )
	if prev2_codeline =~ '\<\(then\|else\|do\)$' && prev_codeline !~ '\<begin$'
		" If the next code line after a single statement branch/loop
		" starts with "end", "except" or "finally", we need an
		" additional unindentation.
		if this_codeline =~ '^\s*\(end;\|except\|finally\|\)$'
			" Note that we don't return from here.
			return indnt - 2 * shiftwidth()
		endif
		return indnt - shiftwidth()
	endif

	" Lines starting with "until" or "end". This rule must be overridden
	" by the one for "end" after a single-statement branch/loop. In
	" other words that rule should come before this one.
	if this_codeline =~ '^\s*\(end\|until\)\>'
		return indnt - shiftwidth()
	endif


	" MISCELLANEOUS THINGS TO CATCH

	" Most "begin"s will have been handled by now. Any remaining
	" "begin"s on their own line should go in column 1.
	if this_codeline =~ '^\s*begin$'
		return 0
	endif


" ________________________________________________________________
" Object/Borland Pascal/Delphi Extensions
"
" Note that extended-pascal is handled here, unless it is simpler to
" handle them in the standard-pascal section above.


	" COLUMN 1 ALWAYS

	" section headers at start of line.
	if this_codeline =~ '^\s*\(interface\|implementation\|uses\|unit\)\>'
		return 0
	endif


	" INDENT ONCE

	" If the PREVIOUS LINE ended in these items, always indent.
	if prev_codeline =~ '^\s*\(unit\|uses\|try\|except\|finally\|private\|protected\|public\|published\)$'
		return indnt + shiftwidth()
	endif

	" ???? Indent "procedure" and "functions" if they appear within an
	" class/object definition. But that means overriding standard-pascal
	" rule where these words always go in column 1.


	" UNINDENT ONCE

	if this_codeline =~ '^\s*\(except\|finally\)$'
		return indnt - shiftwidth()
	endif

	if this_codeline =~ '^\s*\(private\|protected\|public\|published\)$'
		return indnt - shiftwidth()
	endif


	" If nothing changed, return same indent.
	return indnt
endfunction

