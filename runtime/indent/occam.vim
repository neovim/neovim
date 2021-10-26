" Vim indent file
" Language:	occam
" Maintainer:	Mario Schweigler <ms44@kent.ac.uk> (Invalid email address)
" 		Doug Kearns <dougkearns@gmail.com>
" Last Change:	23 April 2003

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

"{{{  Settings
" Set the occam indent function
setlocal indentexpr=GetOccamIndent()
" Indent after new line and after initial colon
setlocal indentkeys=o,O,0=:
"}}}

" Only define the function once
if exists("*GetOccamIndent")
  finish
endif
let s:keepcpo= &cpo
set cpo&vim

"{{{  Indent definitions
" Define carriage return indent
let s:FirstLevelIndent = '^\C\s*\(IF\|ALT\|PRI\s\+ALT\|PAR\|SEQ\|PRI\s\+PAR\|WHILE\|VALOF\|CLAIM\|FORKING\)\>\|\(--.*\)\@<!\(\<PROC\>\|??\|\<CASE\>\s*\(--.*\)\=\_$\)'
let s:FirstLevelNonColonEndIndent = '^\C\s*PROTOCOL\>\|\(--.*\)\@<!\<\(\(CHAN\|DATA\)\s\+TYPE\|FUNCTION\)\>'
let s:SecondLevelIndent = '^\C\s*\(IF\|ALT\|PRI\s\+ALT\)\>\|\(--.*\)\@<!?\s*\<CASE\>\s*\(--.*\)\=\_$'
let s:SecondLevelNonColonEndIndent = '\(--.*\)\@<!\<\(CHAN\|DATA\)\s\+TYPE\>'

" Define colon indent
let s:ColonIndent = '\(--.*\)\@<!\<PROC\>'
let s:ColonNonColonEndIndent = '^\C\s*PROTOCOL\>\|\(--.*\)\@<!\<\(\(CHAN\|DATA\)\s\+TYPE\|FUNCTION\)\>'

let s:ColonEnd = '\(--.*\)\@<!:\s*\(--.*\)\=$'
let s:ColonStart = '^\s*:\s*\(--.*\)\=$'

" Define comment
let s:CommentLine = '^\s*--'
"}}}

"{{{  function GetOccamIndent()
" Auxiliary function to get the correct indent for a line of occam code
function GetOccamIndent()

  " Ensure magic is on
  let save_magic = &magic
  setlocal magic

  " Get reference line number
  let linenum = prevnonblank(v:lnum - 1)
  while linenum > 0 && getline(linenum) =~ s:CommentLine
    let linenum = prevnonblank(linenum - 1)
  endwhile

  " Get current indent
  let curindent = indent(linenum)

  " Get current line
  let line = getline(linenum)

  " Get previous line number
  let prevlinenum = prevnonblank(linenum - 1)
  while prevlinenum > 0 && getline(prevlinenum) =~ s:CommentLine
    let prevlinenum = prevnonblank(prevlinenum - 1)
  endwhile

  " Get previous line
  let prevline = getline(prevlinenum)

  " Colon indent
  if getline(v:lnum) =~ s:ColonStart

    let found = 0

    while found < 1

      if line =~ s:ColonStart
	let found = found - 1
      elseif line =~ s:ColonIndent || (line =~ s:ColonNonColonEndIndent && line !~ s:ColonEnd)
	let found = found + 1
      endif

      if found < 1
	let linenum = prevnonblank(linenum - 1)
	if linenum > 0
	  let line = getline(linenum)
	else
	  let found = 1
	endif
      endif

    endwhile

    if linenum > 0
      let curindent = indent(linenum)
    else
      let colonline = getline(v:lnum)
      let tabstr = ''
      while strlen(tabstr) < &tabstop
	let tabstr = ' ' . tabstr
      endwhile
      let colonline = substitute(colonline, '\t', tabstr, 'g')
      let curindent = match(colonline, ':')
    endif

    " Restore magic
    if !save_magic|setlocal nomagic|endif

    return curindent
  endif

  if getline(v:lnum) =~ '^\s*:'
    let colonline = getline(v:lnum)
    let tabstr = ''
    while strlen(tabstr) < &tabstop
      let tabstr = ' ' . tabstr
    endwhile
    let colonline = substitute(colonline, '\t', tabstr, 'g')
    let curindent = match(colonline, ':')

    " Restore magic
    if !save_magic|setlocal nomagic|endif

    return curindent
  endif

  " Carriage return indenat
  if line =~ s:FirstLevelIndent || (line =~ s:FirstLevelNonColonEndIndent && line !~ s:ColonEnd)
	\ || (line !~ s:ColonStart && (prevline =~ s:SecondLevelIndent
	\ || (prevline =~ s:SecondLevelNonColonEndIndent && prevline !~ s:ColonEnd)))
    let curindent = curindent + shiftwidth()

    " Restore magic
    if !save_magic|setlocal nomagic|endif

    return curindent
  endif

  " Commented line
  if getline(prevnonblank(v:lnum - 1)) =~ s:CommentLine

    " Restore magic
    if !save_magic|setlocal nomagic|endif

    return indent(prevnonblank(v:lnum - 1))
  endif

  " Look for previous second level IF / ALT / PRI ALT
  let found = 0

  while !found

    if indent(prevlinenum) == curindent - shiftwidth()
      let found = 1
    endif

    if !found
      let prevlinenum = prevnonblank(prevlinenum - 1)
      while prevlinenum > 0 && getline(prevlinenum) =~ s:CommentLine
	let prevlinenum = prevnonblank(prevlinenum - 1)
      endwhile
      if prevlinenum == 0
	let found = 1
      endif
    endif

  endwhile

  if prevlinenum > 0
    if getline(prevlinenum) =~ s:SecondLevelIndent
      let curindent = curindent + shiftwidth()
    endif
  endif

  " Restore magic
  if !save_magic|setlocal nomagic|endif

  return curindent

endfunction
"}}}

let &cpo = s:keepcpo
unlet s:keepcpo
