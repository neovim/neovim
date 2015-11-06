" Vim indent file
" Language:	R
" Author:	Jakson Alves de Aquino <jalvesaq@gmail.com>
" Last Change:	Thu Mar 26, 2015  05:36PM


" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal indentkeys=0{,0},:,!^F,o,O,e
setlocal indentexpr=GetRIndent()

" Only define the function once.
if exists("*GetRIndent")
  finish
endif

" Options to make the indentation more similar to Emacs/ESS:
if !exists("g:r_indent_align_args")
  let g:r_indent_align_args = 1
endif
if !exists("g:r_indent_ess_comments")
  let g:r_indent_ess_comments = 0
endif
if !exists("g:r_indent_comment_column")
  let g:r_indent_comment_column = 40
endif
if ! exists("g:r_indent_ess_compatible")
  let g:r_indent_ess_compatible = 0
endif
if ! exists("g:r_indent_op_pattern")
  let g:r_indent_op_pattern = '\(+\|-\|\*\|/\|=\|\~\|%\)$'
endif

function s:RDelete_quotes(line)
  let i = 0
  let j = 0
  let line1 = ""
  let llen = strlen(a:line)
  while i < llen
    if a:line[i] == '"'
      let i += 1
      let line1 = line1 . 's'
      while !(a:line[i] == '"' && ((i > 1 && a:line[i-1] == '\' && a:line[i-2] == '\') || a:line[i-1] != '\')) && i < llen
        let i += 1
      endwhile
      if a:line[i] == '"'
        let i += 1
      endif
    else
      if a:line[i] == "'"
        let i += 1
        let line1 = line1 . 's'
        while !(a:line[i] == "'" && ((i > 1 && a:line[i-1] == '\' && a:line[i-2] == '\') || a:line[i-1] != '\')) && i < llen
          let i += 1
        endwhile
        if a:line[i] == "'"
          let i += 1
        endif
      else
        if a:line[i] == "`"
          let i += 1
          let line1 = line1 . 's'
          while a:line[i] != "`" && i < llen
            let i += 1
          endwhile
          if a:line[i] == "`"
            let i += 1
          endif
        endif
      endif
    endif
    if i == llen
      break
    endif
    let line1 = line1 . a:line[i]
    let j += 1
    let i += 1
  endwhile
  return line1
endfunction

" Convert foo(bar()) int foo()
function s:RDelete_parens(line)
  if s:Get_paren_balance(a:line, "(", ")") != 0
    return a:line
  endif
  let i = 0
  let j = 0
  let line1 = ""
  let llen = strlen(a:line)
  while i < llen
    let line1 = line1 . a:line[i]
    if a:line[i] == '('
      let nop = 1
      while nop > 0 && i < llen
        let i += 1
        if a:line[i] == ')'
          let nop -= 1
        else
          if a:line[i] == '('
            let nop += 1
          endif
        endif
      endwhile
      let line1 = line1 . a:line[i]
    endif
    let i += 1
  endwhile
  return line1
endfunction

function! s:Get_paren_balance(line, o, c)
  let line2 = substitute(a:line, a:o, "", "g")
  let openp = strlen(a:line) - strlen(line2)
  let line3 = substitute(line2, a:c, "", "g")
  let closep = strlen(line2) - strlen(line3)
  return openp - closep
endfunction

function! s:Get_matching_brace(linenr, o, c, delbrace)
  let line = SanitizeRLine(getline(a:linenr))
  if a:delbrace == 1
    let line = substitute(line, '{$', "", "")
  endif
  let pb = s:Get_paren_balance(line, a:o, a:c)
  let i = a:linenr
  while pb != 0 && i > 1
    let i -= 1
    let pb += s:Get_paren_balance(SanitizeRLine(getline(i)), a:o, a:c)
  endwhile
  return i
endfunction

" This function is buggy because there 'if's without 'else'
" It must be rewritten relying more on indentation
function! s:Get_matching_if(linenr, delif)
  let line = SanitizeRLine(getline(a:linenr))
  if a:delif
    let line = substitute(line, "if", "", "g")
  endif
  let elsenr = 0
  let i = a:linenr
  let ifhere = 0
  while i > 0
    let line2 = substitute(line, '\<else\>', "xxx", "g")
    let elsenr += strlen(line) - strlen(line2)
    if line =~ '.*\s*if\s*()' || line =~ '.*\s*if\s*()'
      let elsenr -= 1
      if elsenr == 0
        let ifhere = i
        break
      endif
    endif
    let i -= 1
    let line = SanitizeRLine(getline(i))
  endwhile
  if ifhere
    return ifhere
  else
    return a:linenr
  endif
endfunction

function! s:Get_last_paren_idx(line, o, c, pb)
  let blc = a:pb
  let line = substitute(a:line, '\t', s:curtabstop, "g")
  let theidx = -1
  let llen = strlen(line)
  let idx = 0
  while idx < llen
    if line[idx] == a:o
      let blc -= 1
      if blc == 0
        let theidx = idx
      endif
    else
      if line[idx] == a:c
        let blc += 1
      endif
    endif
    let idx += 1
  endwhile
  return theidx + 1
endfunction

" Get previous relevant line. Search back until getting a line that isn't
" comment or blank
function s:Get_prev_line(lineno)
  let lnum = a:lineno - 1
  let data = getline( lnum )
  while lnum > 0 && (data =~ '^\s*#' || data =~ '^\s*$')
    let lnum = lnum - 1
    let data = getline( lnum )
  endwhile
  return lnum
endfunction

" This function is also used by r-plugin/common_global.vim
" Delete from '#' to the end of the line, unless the '#' is inside a string.
function SanitizeRLine(line)
  let newline = s:RDelete_quotes(a:line)
  let newline = s:RDelete_parens(newline)
  let newline = substitute(newline, '#.*', "", "")
  let newline = substitute(newline, '\s*$', "", "")
  if &filetype == "rhelp" && newline =~ '^\\method{.*}{.*}(.*'
    let newline = substitute(newline, '^\\method{\(.*\)}{.*}', '\1', "")
  endif
  return newline
endfunction

function GetRIndent()

  let clnum = line(".")    " current line

  let cline = getline(clnum)
  if cline =~ '^\s*#'
    if g:r_indent_ess_comments == 1
      if cline =~ '^\s*###'
        return 0
      endif
      if cline !~ '^\s*##'
        return g:r_indent_comment_column
      endif
    endif
  endif

  let cline = SanitizeRLine(cline)

  if cline =~ '^\s*}' || cline =~ '^\s*}\s*)$'
    let indline = s:Get_matching_brace(clnum, '{', '}', 1)
    if indline > 0 && indline != clnum
      let iline = SanitizeRLine(getline(indline))
      if s:Get_paren_balance(iline, "(", ")") == 0 || iline =~ '(\s*{$'
        return indent(indline)
      else
        let indline = s:Get_matching_brace(indline, '(', ')', 1)
        return indent(indline)
      endif
    endif
  endif

  " Find the first non blank line above the current line
  let lnum = s:Get_prev_line(clnum)
  " Hit the start of the file, use zero indent.
  if lnum == 0
    return 0
  endif

  let line = SanitizeRLine(getline(lnum))

  if &filetype == "rhelp"
    if cline =~ '^\\dontshow{' || cline =~ '^\\dontrun{' || cline =~ '^\\donttest{' || cline =~ '^\\testonly{'
      return 0
    endif
    if line =~ '^\\examples{' || line =~ '^\\usage{' || line =~ '^\\dontshow{' || line =~ '^\\dontrun{' || line =~ '^\\donttest{' || line =~ '^\\testonly{'
      return 0
    endif
  endif

  if &filetype == "rnoweb" && line =~ "^<<.*>>="
    return 0
  endif

  if cline =~ '^\s*{'
    if g:r_indent_ess_compatible && line =~ ')$'
      let nlnum = lnum
      let nline = line
      while s:Get_paren_balance(nline, '(', ')') < 0
        let nlnum = s:Get_prev_line(nlnum)
        let nline = SanitizeRLine(getline(nlnum)) . nline
      endwhile
      if nline =~ '^\s*function\s*(' && indent(nlnum) == &sw
        return 0
      endif
    endif
    if s:Get_paren_balance(line, "(", ")") == 0
      return indent(lnum)
    endif
  endif

  " line is an incomplete command:
  if line =~ '\<\(if\|while\|for\|function\)\s*()$' || line =~ '\<else$' || line =~ '<-$'
    return indent(lnum) + &sw
  endif

  " Deal with () and []

  let pb = s:Get_paren_balance(line, '(', ')')

  if line =~ '^\s*{$' || line =~ '(\s*{' || (pb == 0 && (line =~ '{$' || line =~ '(\s*{$'))
    return indent(lnum) + &sw
  endif

  let s:curtabstop = repeat(' ', &tabstop)

  if g:r_indent_align_args == 1
    if pb > 0 && line =~ '{$'
      return s:Get_last_paren_idx(line, '(', ')', pb) + &sw
    endif

    let bb = s:Get_paren_balance(line, '[', ']')

    if pb > 0
      if &filetype == "rhelp"
        let ind = s:Get_last_paren_idx(line, '(', ')', pb)
      else
        let ind = s:Get_last_paren_idx(getline(lnum), '(', ')', pb)
      endif
      return ind
    endif

    if pb < 0 && line =~ '.*[,&|\-\*+<>]$'
      let lnum = s:Get_prev_line(lnum)
      while pb < 1 && lnum > 0
        let line = SanitizeRLine(getline(lnum))
        let line = substitute(line, '\t', s:curtabstop, "g")
        let ind = strlen(line)
        while ind > 0
          if line[ind] == ')'
            let pb -= 1
          else
            if line[ind] == '('
              let pb += 1
            endif
          endif
          if pb == 1
            return ind + 1
          endif
          let ind -= 1
        endwhile
        let lnum -= 1
      endwhile
      return 0
    endif

    if bb > 0
      let ind = s:Get_last_paren_idx(getline(lnum), '[', ']', bb)
      return ind
    endif
  endif

  let post_block = 0
  if line =~ '}$'
    let lnum = s:Get_matching_brace(lnum, '{', '}', 0)
    let line = SanitizeRLine(getline(lnum))
    if lnum > 0 && line =~ '^\s*{'
      let lnum = s:Get_prev_line(lnum)
      let line = SanitizeRLine(getline(lnum))
    endif
    let pb = s:Get_paren_balance(line, '(', ')')
    let post_block = 1
  endif

  " Indent after operator pattern
  let olnum = s:Get_prev_line(lnum)
  let oline = getline(olnum)
  if olnum > 0
    if line =~ g:r_indent_op_pattern
      if oline =~ g:r_indent_op_pattern
        return indent(lnum)
      else
        return indent(lnum) + &sw
      endif
    else
      if oline =~ g:r_indent_op_pattern
        return indent(lnum) - &sw
      endif
    endif
  endif

  let post_fun = 0
  if pb < 0 && line !~ ')\s*[,&|\-\*+<>]$'
    let post_fun = 1
    while pb < 0 && lnum > 0
      let lnum -= 1
      let linepiece = SanitizeRLine(getline(lnum))
      let pb += s:Get_paren_balance(linepiece, "(", ")")
      let line = linepiece . line
    endwhile
    if line =~ '{$' && post_block == 0
      return indent(lnum) + &sw
    endif

    " Now we can do some tests again
    if cline =~ '^\s*{'
      return indent(lnum)
    endif
    if post_block == 0
      let newl = SanitizeRLine(line)
      if newl =~ '\<\(if\|while\|for\|function\)\s*()$' || newl =~ '\<else$' || newl =~ '<-$'
        return indent(lnum) + &sw
      endif
    endif
  endif

  if cline =~ '^\s*else'
    if line =~ '<-\s*if\s*()'
      return indent(lnum) + &sw
    else
      if line =~ '\<if\s*()'
        return indent(lnum)
      else
        return indent(lnum) - &sw
      endif
    endif
  endif

  let bb = s:Get_paren_balance(line, '[', ']')
  if bb < 0 && line =~ '.*]'
    while bb < 0 && lnum > 0
      let lnum -= 1
      let linepiece = SanitizeRLine(getline(lnum))
      let bb += s:Get_paren_balance(linepiece, "[", "]")
      let line = linepiece . line
    endwhile
    let line = s:RDelete_parens(line)
  endif

  let plnum = s:Get_prev_line(lnum)
  let ppost_else = 0
  if plnum > 0
    let pline = SanitizeRLine(getline(plnum))
    let ppost_block = 0
    if pline =~ '}$'
      let ppost_block = 1
      let plnum = s:Get_matching_brace(plnum, '{', '}', 0)
      let pline = SanitizeRLine(getline(plnum))
      if pline =~ '^\s*{$' && plnum > 0
        let plnum = s:Get_prev_line(plnum)
        let pline = SanitizeRLine(getline(plnum))
      endif
    endif

    if pline =~ 'else$'
      let ppost_else = 1
      let plnum = s:Get_matching_if(plnum, 0)
      let pline = SanitizeRLine(getline(plnum))
    endif

    if pline =~ '^\s*else\s*if\s*('
      let pplnum = s:Get_prev_line(plnum)
      let ppline = SanitizeRLine(getline(pplnum))
      while ppline =~ '^\s*else\s*if\s*(' || ppline =~ '^\s*if\s*()\s*\S$'
        let plnum = pplnum
        let pline = ppline
        let pplnum = s:Get_prev_line(plnum)
        let ppline = SanitizeRLine(getline(pplnum))
      endwhile
      while ppline =~ '\<\(if\|while\|for\|function\)\s*()$' || ppline =~ '\<else$' || ppline =~ '<-$'
        let plnum = pplnum
        let pline = ppline
        let pplnum = s:Get_prev_line(plnum)
        let ppline = SanitizeRLine(getline(pplnum))
      endwhile
    endif

    let ppb = s:Get_paren_balance(pline, '(', ')')
    if ppb < 0 && (pline =~ ')\s*{$' || pline =~ ')$')
      while ppb < 0 && plnum > 0
        let plnum -= 1
        let linepiece = SanitizeRLine(getline(plnum))
        let ppb += s:Get_paren_balance(linepiece, "(", ")")
        let pline = linepiece . pline
      endwhile
      let pline = s:RDelete_parens(pline)
    endif
  endif

  let ind = indent(lnum)
  let pind = indent(plnum)

  if g:r_indent_align_args == 0 && pb != 0
    let ind += pb * &sw
    return ind
  endif

  if g:r_indent_align_args == 0 && bb != 0
    let ind += bb * &sw
    return ind
  endif

  if ind == pind || (ind == (pind  + &sw) && pline =~ '{$' && ppost_else == 0)
    return ind
  endif

  let pline = getline(plnum)
  let pbb = s:Get_paren_balance(pline, '[', ']')

  while pind < ind && plnum > 0 && ppb == 0 && pbb == 0
    let ind = pind
    let plnum = s:Get_prev_line(plnum)
    let pline = getline(plnum)
    let ppb = s:Get_paren_balance(pline, '(', ')')
    let pbb = s:Get_paren_balance(pline, '[', ']')
    while pline =~ '^\s*else'
      let plnum = s:Get_matching_if(plnum, 1)
      let pline = getline(plnum)
      let ppb = s:Get_paren_balance(pline, '(', ')')
      let pbb = s:Get_paren_balance(pline, '[', ']')
    endwhile
    let pind = indent(plnum)
    if ind == (pind  + &sw) && pline =~ '{$'
      return ind
    endif
  endwhile

  return ind

endfunction

" vim: sw=2
