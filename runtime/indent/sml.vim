" Vim indent file
" Language:     SML
" Maintainer:	Saikat Guha <sg266@cornell.edu>
" 				Hubert Chao <hc85@cornell.edu>
" Original OCaml Version:
" 				Jean-Francois Yuen  <jfyuen@ifrance.com>
"               Mike Leary          <leary@nwlink.com>
"               Markus Mottl        <markus@oefai.at>
" OCaml URL:    http://www.oefai.at/~markus/vim/indent/ocaml.vim
" Last Change:  2003 Jan 04	- Adapted to SML
" 				2002 Nov 06 - Some fixes (JY)
"               2002 Oct 28 - Fixed bug with indentation of ']' (MM)
"               2002 Oct 22 - Major rewrite (JY)

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal expandtab
setlocal indentexpr=GetSMLIndent()
setlocal indentkeys+=0=and,0=else,0=end,0=handle,0=if,0=in,0=let,0=then,0=val,0=fun,0=\|,0=*),0)
setlocal nolisp
setlocal nosmartindent
setlocal textwidth=80
setlocal shiftwidth=2

" Comment formatting
if (has("comments"))
  set comments=sr:(*,mb:*,ex:*)
  set fo=cqort
endif

" Only define the function once.
"if exists("*GetSMLIndent")
"finish
"endif

" Define some patterns:
let s:beflet = '^\s*\(initializer\|method\|try\)\|\(\<\(begin\|do\|else\|in\|then\|try\)\|->\|;\)\s*$'
let s:letpat = '^\s*\(let\|type\|module\|class\|open\|exception\|val\|include\|external\)\>'
let s:letlim = '\(\<\(sig\|struct\)\|;;\)\s*$'
let s:lim = '^\s*\(exception\|external\|include\|let\|module\|open\|type\|val\)\>'
let s:module = '\<\%(let\|sig\|struct\)\>'
let s:obj = '^\s*\(constraint\|inherit\|initializer\|method\|val\)\>\|\<\(object\|object\s*(.*)\)\s*$'
let s:type = '^\s*\%(let\|type\)\>.*='
let s:val = '^\s*\(val\|external\)\>.*:'

" Skipping pattern, for comments
function! s:SkipPattern(lnum, pat)
  let def = prevnonblank(a:lnum - 1)
  while def > 0 && getline(def) =~ a:pat
    let def = prevnonblank(def - 1)
  endwhile
  return def
endfunction

" Indent for ';;' to match multiple 'let'
function! s:GetInd(lnum, pat, lim)
  let llet = search(a:pat, 'bW')
  let old = indent(a:lnum)
  while llet > 0
    let old = indent(llet)
    let nb = s:SkipPattern(llet, '^\s*(\*.*\*)\s*$')
    if getline(nb) =~ a:lim
      return old
    endif
    let llet = search(a:pat, 'bW')
  endwhile
  return old
endfunction

" Indent pairs
function! s:FindPair(pstart, pmid, pend)
  call search(a:pend, 'bW')
"  return indent(searchpair(a:pstart, a:pmid, a:pend, 'bWn', 'synIDattr(synID(line("."), col("."), 0), "name") =~? "string\\|comment"'))
  let lno = searchpair(a:pstart, a:pmid, a:pend, 'bW', 'synIDattr(synID(line("."), col("."), 0), "name") =~? "string\\|comment"')
  if lno == -1
	return indent(lno)
  else
	return col(".") - 1
  endif
endfunction

function! s:FindLet(pstart, pmid, pend)
  call search(a:pend, 'bW')
"  return indent(searchpair(a:pstart, a:pmid, a:pend, 'bWn', 'synIDattr(synID(line("."), col("."), 0), "name") =~? "string\\|comment"'))
  let lno = searchpair(a:pstart, a:pmid, a:pend, 'bW', 'synIDattr(synID(line("."), col("."), 0), "name") =~? "string\\|comment"')
  let moduleLine = getline(lno)
  if lno == -1 || moduleLine =~ '^\s*\(fun\|structure\|signature\)\>'
	return indent(lno)
  else
	return col(".") - 1
  endif
endfunction

" Indent 'let'
"function! s:FindLet(pstart, pmid, pend)
"  call search(a:pend, 'bW')
"  return indent(searchpair(a:pstart, a:pmid, a:pend, 'bWn', 'synIDattr(synID(line("."), col("."), 0), "name") =~? "string\\|comment" || getline(".") =~ "^\\s*let\\>.*=.*\\<in\\s*$" || getline(prevnonblank(".") - 1) =~ "^\\s*let\\>.*=\\s*$\\|" . s:beflet'))
"endfunction

function! GetSMLIndent()
  " Find a non-blank line above the current line.
  let lnum = prevnonblank(v:lnum - 1)

  " At the start of the file use zero indent.
  if lnum == 0
    return 0
  endif

  let ind = indent(lnum)
  let lline = getline(lnum)

	" Return double 'shiftwidth' after lines matching:
	if lline =~ '^\s*|.*=>\s*$'
		return ind + 2 *shiftwidth()
	elseif lline =~ '^\s*val\>.*=\s*$'
		return ind + shiftwidth()
	endif

  let line = getline(v:lnum)

	" Indent lines starting with 'end' to matching module
	if line =~ '^\s*end\>'
		return s:FindLet(s:module, '', '\<end\>')

	" Match 'else' with 'if'
	elseif line =~ '^\s*else\>'
	  	if lline !~ '^\s*\(if\|else\|then\)\>'
				return s:FindPair('\<if\>', '', '\<then\>')
	  	else
		  return ind
		endif

	" Match 'then' with 'if'
	elseif line =~ '^\s*then\>'
  	if lline !~ '^\s*\(if\|else\|then\)\>'
		  return s:FindPair('\<if\>', '', '\<then\>')
	else
	  return ind
	endif

	" Indent if current line begins with ']'
	elseif line =~ '^\s*\]'
		return s:FindPair('\[','','\]')

  " Indent current line starting with 'in' to last matching 'let'
	elseif line =~ '^\s*in\>'
		let ind = s:FindLet('\<let\>','','\<in\>')

	" Indent from last matching module if line matches:
	elseif line =~ '^\s*\(fun\|val\|open\|structure\|and\|datatype\|type\|exception\)\>'
		cursor(lnum,1)
  		let lastModule = indent(searchpair(s:module, '', '\<end\>', 'bWn', 'synIDattr(synID(line("."), col("."), 0), "name") =~? "string\\|comment"'))
		if lastModule == -1
			return 0
		else
			return lastModule + shiftwidth()
		endif

	" Indent lines starting with '|' from matching 'case', 'handle'
	elseif line =~ '^\s*|'
		" cursor(lnum,1)
		let lastSwitch = search('\<\(case\|handle\|fun\|datatype\)\>','bW')
		let switchLine = getline(lastSwitch)
		let switchLineIndent = indent(lastSwitch)
		if lline =~ '^\s*|'
		  return ind
		endif
		if switchLine =~ '\<case\>'
			return col(".") + 2
		elseif switchLine =~ '\<handle\>'
			return switchLineIndent + shiftwidth()
		elseif switchLine =~ '\<datatype\>'
			call search('=')
			return col(".") - 1
		else
			return switchLineIndent + 2
		endif


  " Indent if last line ends with 'sig', 'struct', 'let', 'then', 'else',
  " 'in'
  elseif lline =~ '\<\(sig\|struct\|let\|in\|then\|else\)\s*$'
		let ind = ind + shiftwidth()

  " Indent if last line ends with 'of', align from 'case'
  elseif lline =~ '\<\(of\)\s*$'
		call search('\<case\>',"bW")
		let ind = col(".")+4

	" Indent if current line starts with 'of'
  elseif line =~ '^\s*of\>'
		call search('\<case\>',"bW")
		let ind = col(".")+1


	" Indent if last line starts with 'fun', 'case', 'fn'
	elseif lline =~ '^\s*\(fun\|fn\|case\)\>'
		let ind = ind + shiftwidth()

	endif

	" Don't indent 'let' if last line started with 'fun', 'fn'
	if line =~ '^\s*let\>'
		if lline =~ '^\s*\(fun\|fn\)'
			let ind = ind - shiftwidth()
		endif
  endif

  return ind

endfunction

" vim:sw=2
