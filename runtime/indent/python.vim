" Vim indent file
" Language:		Python
" Maintainer:		Bram Moolenaar <Bram@vim.org>
" Original Author:	David Bustos <bustos@caltech.edu>
" Last Change:		2019 Feb 21

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

" Some preliminary settings
setlocal nolisp		" Make sure lisp indenting doesn't supersede us
setlocal autoindent	" indentexpr isn't much help otherwise

setlocal indentexpr=GetPythonIndent(v:lnum)
setlocal indentkeys+=<:>,=elif,=except

" Only define the function once.
if exists("*GetPythonIndent")
  finish
endif
let s:keepcpo= &cpo
set cpo&vim

" Come here when loading the script the first time.

let s:maxoff = 50	" maximum number of lines to look backwards for ()

function GetPythonIndent(lnum)

  " If this line is explicitly joined: If the previous line was also joined,
  " line it up with that one, otherwise add two 'shiftwidth'
  if getline(a:lnum - 1) =~ '\\$'
    if a:lnum > 1 && getline(a:lnum - 2) =~ '\\$'
      return indent(a:lnum - 1)
    endif
    return indent(a:lnum - 1) + (exists("g:pyindent_continue") ? eval(g:pyindent_continue) : (shiftwidth() * 2))
  endif

  " If the start of the line is in a string don't change the indent.
  if has('syntax_items')
	\ && synIDattr(synID(a:lnum, 1, 1), "name") =~ "String$"
    return -1
  endif

  " Search backwards for the previous non-empty line.
  let plnum = prevnonblank(v:lnum - 1)

  if plnum == 0
    " This is the first non-empty line, use zero indent.
    return 0
  endif

  call cursor(plnum, 1)

  " Identing inside parentheses can be very slow, regardless of the searchpair()
  " timeout, so let the user disable this feature if he doesn't need it
  let disable_parentheses_indenting = get(g:, "pyindent_disable_parentheses_indenting", 0)

  if disable_parentheses_indenting == 1
    let plindent = indent(plnum)
    let plnumstart = plnum
  else
    " searchpair() can be slow sometimes, limit the time to 150 msec or what is
    " put in g:pyindent_searchpair_timeout
    let searchpair_stopline = 0
    let searchpair_timeout = get(g:, 'pyindent_searchpair_timeout', 150)

    " If the previous line is inside parenthesis, use the indent of the starting
    " line.
    " Trick: use the non-existing "dummy" variable to break out of the loop when
    " going too far back.
    let parlnum = searchpair('(\|{\|\[', '', ')\|}\|\]', 'nbW',
            \ "line('.') < " . (plnum - s:maxoff) . " ? dummy :"
            \ . " synIDattr(synID(line('.'), col('.'), 1), 'name')"
            \ . " =~ '\\(Comment\\|Todo\\|String\\)$'",
            \ searchpair_stopline, searchpair_timeout)
    if parlnum > 0
      let plindent = indent(parlnum)
      let plnumstart = parlnum
    else
      let plindent = indent(plnum)
      let plnumstart = plnum
    endif

    " When inside parenthesis: If at the first line below the parenthesis add
    " two 'shiftwidth', otherwise same as previous line.
    " i = (a
    "       + b
    "       + c)
    call cursor(a:lnum, 1)
    let p = searchpair('(\|{\|\[', '', ')\|}\|\]', 'bW',
            \ "line('.') < " . (a:lnum - s:maxoff) . " ? dummy :"
            \ . " synIDattr(synID(line('.'), col('.'), 1), 'name')"
            \ . " =~ '\\(Comment\\|Todo\\|String\\)$'",
            \ searchpair_stopline, searchpair_timeout)
    if p > 0
      if p == plnum
        " When the start is inside parenthesis, only indent one 'shiftwidth'.
        let pp = searchpair('(\|{\|\[', '', ')\|}\|\]', 'bW',
            \ "line('.') < " . (a:lnum - s:maxoff) . " ? dummy :"
            \ . " synIDattr(synID(line('.'), col('.'), 1), 'name')"
            \ . " =~ '\\(Comment\\|Todo\\|String\\)$'",
            \ searchpair_stopline, searchpair_timeout)
        if pp > 0
          return indent(plnum) + (exists("g:pyindent_nested_paren") ? eval(g:pyindent_nested_paren) : shiftwidth())
        endif
        return indent(plnum) + (exists("g:pyindent_open_paren") ? eval(g:pyindent_open_paren) : (shiftwidth() * 2))
      endif
      if plnumstart == p
        return indent(plnum)
      endif
      return plindent
    endif

  endif


  " Get the line and remove a trailing comment.
  " Use syntax highlighting attributes when possible.
  let pline = getline(plnum)
  let pline_len = strlen(pline)
  if has('syntax_items')
    " If the last character in the line is a comment, do a binary search for
    " the start of the comment.  synID() is slow, a linear search would take
    " too long on a long line.
    if synIDattr(synID(plnum, pline_len, 1), "name") =~ "\\(Comment\\|Todo\\)$"
      let min = 1
      let max = pline_len
      while min < max
	let col = (min + max) / 2
	if synIDattr(synID(plnum, col, 1), "name") =~ "\\(Comment\\|Todo\\)$"
	  let max = col
	else
	  let min = col + 1
	endif
      endwhile
      let pline = strpart(pline, 0, min - 1)
    endif
  else
    let col = 0
    while col < pline_len
      if pline[col] == '#'
	let pline = strpart(pline, 0, col)
	break
      endif
      let col = col + 1
    endwhile
  endif

  " If the previous line ended with a colon, indent this line
  if pline =~ ':\s*$'
    return plindent + shiftwidth()
  endif

  " If the previous line was a stop-execution statement...
  if getline(plnum) =~ '^\s*\(break\|continue\|raise\|return\|pass\)\>'
    " See if the user has already dedented
    if indent(a:lnum) > indent(plnum) - shiftwidth()
      " If not, recommend one dedent
      return indent(plnum) - shiftwidth()
    endif
    " Otherwise, trust the user
    return -1
  endif

  " If the current line begins with a keyword that lines up with "try"
  if getline(a:lnum) =~ '^\s*\(except\|finally\)\>'
    let lnum = a:lnum - 1
    while lnum >= 1
      if getline(lnum) =~ '^\s*\(try\|except\)\>'
	let ind = indent(lnum)
	if ind >= indent(a:lnum)
	  return -1	" indent is already less than this
	endif
	return ind	" line up with previous try or except
      endif
      let lnum = lnum - 1
    endwhile
    return -1		" no matching "try"!
  endif

  " If the current line begins with a header keyword, dedent
  if getline(a:lnum) =~ '^\s*\(elif\|else\)\>'

    " Unless the previous line was a one-liner
    if getline(plnumstart) =~ '^\s*\(for\|if\|try\)\>'
      return plindent
    endif

    " Or the user has already dedented
    if indent(a:lnum) <= plindent - shiftwidth()
      return -1
    endif

    return plindent - shiftwidth()
  endif

  " When after a () construct we probably want to go back to the start line.
  " a = (b
  "       + c)
  " here
  if parlnum > 0
    return plindent
  endif

  return -1

endfunction

let &cpo = s:keepcpo
unlet s:keepcpo

" vim:sw=2
