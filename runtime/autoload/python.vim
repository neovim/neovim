" Support for Python indenting, see runtime/indent/python.vim

let s:keepcpo= &cpo
set cpo&vim

" need to inspect some old g:pyindent_* variables to be backward compatible
let g:python_indent = extend(get(g:, 'python_indent', {}), #{
  \ closed_paren_align_last_line: v:true,
  \ open_paren: get(g:, 'pyindent_open_paren', 'shiftwidth() * 2'),
  \ nested_paren: get(g:, 'pyindent_nested_paren', 'shiftwidth()'),
  \ continue: get(g:, 'pyindent_continue', 'shiftwidth() * 2'),
  "\ searchpair() can be slow, limit the time to 150 msec or what is put in
  "\ g:python_indent.searchpair_timeout
  \ searchpair_timeout: get(g:, 'pyindent_searchpair_timeout', 150),
  "\ Identing inside parentheses can be very slow, regardless of the searchpair()
  "\ timeout, so let the user disable this feature if he doesn't need it
  \ disable_parentheses_indenting: get(g:, 'pyindent_disable_parentheses_indenting', v:false),
  \ }, 'keep')

let s:maxoff = 50       " maximum number of lines to look backwards for ()

function s:SearchBracket(fromlnum, flags)
  " VIM_INDENT_TEST_TRACE_START
  return searchpairpos('[[({]', '', '[])}]', a:flags,
          \ {-> synstack('.', col('.'))
          \ ->indexof({_, id -> synIDattr(id, 'name') =~ '\%(Comment\|Todo\|String\)$'}) >= 0},
          \ [0, a:fromlnum - s:maxoff]->max(), g:python_indent.searchpair_timeout)
  " VIM_INDENT_TEST_TRACE_END python#s:SearchBracket
endfunction

" See if the specified line is already user-dedented from the expected value.
function s:Dedented(lnum, expected)
  return indent(a:lnum) <= a:expected - shiftwidth()
endfunction

" Some other filetypes which embed Python have slightly different indent
" rules (e.g. bitbake). Those filetypes can pass an extra funcref to this
" function which is evaluated below.
function python#GetIndent(lnum, ...)
  let ExtraFunc = a:0 > 0 ? a:1 : 0

  " If this line is explicitly joined: If the previous line was also joined,
  " line it up with that one, otherwise add two 'shiftwidth'
  if getline(a:lnum - 1) =~ '\\$'
    if a:lnum > 1 && getline(a:lnum - 2) =~ '\\$'
      return indent(a:lnum - 1)
    endif
    return indent(a:lnum - 1) + get(g:, 'pyindent_continue', g:python_indent.continue)->eval()
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

  if g:python_indent.disable_parentheses_indenting == 1
    let plindent = indent(plnum)
    let plnumstart = plnum
  else
    " Indent inside parens.
    " Align with the open paren unless it is at the end of the line.
    " E.g.
    "     open_paren_not_at_EOL(100,
    "                           (200,
    "                            300),
    "                           400)
    "     open_paren_at_EOL(
    "         100, 200, 300, 400)
    call cursor(a:lnum, 1)
    let [parlnum, parcol] = s:SearchBracket(a:lnum, 'nbW')
    if parlnum > 0
      if parcol != col([parlnum, '$']) - 1
        return parcol
      elseif getline(a:lnum) =~ '^\s*[])}]' && !g:python_indent.closed_paren_align_last_line
        return indent(parlnum)
      endif
    endif

    call cursor(plnum, 1)

    " If the previous line is inside parenthesis, use the indent of the starting
    " line.
    let [parlnum, _] = s:SearchBracket(plnum, 'nbW')
    if parlnum > 0
      if a:0 > 0 && ExtraFunc(parlnum)
        " We may have found the opening brace of a bitbake Python task, e.g. 'python do_task {'
        " If so, ignore it here - it will be handled later.
        let parlnum = 0
        let plindent = indent(plnum)
        let plnumstart = plnum
      else
        let plindent = indent(parlnum)
        let plnumstart = parlnum
      endif
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
    let [p, _] = s:SearchBracket(a:lnum, 'bW')
    if p > 0
      if a:0 > 0 && ExtraFunc(p)
        " Currently only used by bitbake
        " Handle first non-empty line inside a bitbake Python task
        if p == plnum
          return shiftwidth()
        endif

        " Handle the user actually trying to close a bitbake Python task
        let line = getline(a:lnum)
        if line =~ '^\s*}'
          return -2
        endif

        " Otherwise ignore the brace
        let p = 0
      else
        if p == plnum
          " When the start is inside parenthesis, only indent one 'shiftwidth'.
          let [pp, _] = s:SearchBracket(a:lnum, 'bW')
          if pp > 0
            return indent(plnum)
              \ + get(g:, 'pyindent_nested_paren', g:python_indent.nested_paren)->eval()
          endif
          return indent(plnum)
            \ + get(g:, 'pyindent_open_paren', g:python_indent.open_paren)->eval()
        endif
        if plnumstart == p
          return indent(plnum)
        endif
        return plindent
      endif
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
    if synstack(plnum, pline_len)
    \ ->indexof({_, id -> synIDattr(id, 'name') =~ '\%(Comment\|Todo\)$'}) >= 0
      let min = 1
      let max = pline_len
      while min < max
	let col = (min + max) / 2
        if synstack(plnum, col)
        \ ->indexof({_, id -> synIDattr(id, 'name') =~ '\%(Comment\|Todo\)$'}) >= 0
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
    if s:Dedented(a:lnum, indent(plnum))
      " If so, trust the user
      return -1
    endif
    " If not, recommend one dedent
    return indent(plnum) - shiftwidth()
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
    if getline(plnumstart) =~ '^\s*\(for\|if\|elif\|try\)\>'
      return plindent
    endif

    " Or the user has already dedented
    if s:Dedented(a:lnum, plindent)
      return -1
    endif

    return plindent - shiftwidth()
  endif

  " When after a () construct we probably want to go back to the start line.
  " a = (b
  "       + c)
  " here
  if parlnum > 0
    " ...unless the user has already dedented
    if s:Dedented(a:lnum, plindent)
        return -1
    else
        return plindent
    endif
  endif

  return -1
endfunction

let &cpo = s:keepcpo
unlet s:keepcpo
