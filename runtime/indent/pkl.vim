" Vim indent file
" Language:		Pkl
" Maintainer:		Jan Claußen <jan DOT claussen10 AT web DOT de>
" Last Change:		2026 Oct 20
"
" Indents the contents of objects, classes, lists, argument lists and
" continuation lines after '=' and '->', like the tree-sitter indent queries
" of Neovim. The contents of multiline strings and block comments are left
" alone, since their indentation is part of the text.

if exists('b:did_indent')
  finish
endif
let b:did_indent = 1

setlocal autoindent nosmartindent nocindent
setlocal indentexpr=GetPklIndent(v:lnum)
setlocal indentkeys=0{,0},0),0],0=else,0=\|,!^F,o,O

let b:undo_indent = 'setl ai< si< cin< inde< indk<'

if exists('*GetPklIndent')
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" Syntax groups whose contents are text, not code
let s:text_groups = 'String\|Comment\|Escape\|Unicode'

function s:IsText(lnum, col) abort
  return synIDattr(synID(a:lnum, a:col, 1), 'name') =~# s:text_groups
endfunction

" Whether the line starts inside a multiline string or block comment
function s:StartsInRegion(lnum) abort
  let col = max([1, match(getline(a:lnum), '\S') + 1])
  for id in synstack(a:lnum, col)
    if synIDattr(id, 'name') =~# 'MultiString\|MultiComment'
      return 1
    endif
  endfor
  return 0
endfunction

" The line where the multiline string or block comment started, that
" contains the given line
function s:RegionStart(lnum) abort
  let lnum = a:lnum
  while lnum > 1 && s:StartsInRegion(lnum)
    let lnum = prevnonblank(lnum - 1)
  endwhile
  return lnum
endfunction

" Skip expression for searchpair(): ignore brackets in strings and comments
let s:skip = 's:IsText(line("."), col("."))'

" The line of the bracket that is closed at the given position
function s:OpeningLine(lnum, col) abort
  let save = getcurpos()
  call cursor(a:lnum, a:col)
  let char = getline(a:lnum)[a:col - 1]
  let pair = {')': '(', ']': '\[', '}': '{'}[char]
  let [lnum, _] = searchpairpos(pair, '', escape(char, ']'), 'bnW', s:skip)
  call setpos('.', save)
  return lnum
endfunction

" Returns the number of brackets that are opened on the line and not closed,
" and the column of the last bracket that closes one of a previous line.
function s:Brackets(lnum) abort
  let line = getline(a:lnum)
  let open = 0
  let last_close = 0
  let col = match(line, '[[\](){}]')
  while col >= 0
    if !s:IsText(a:lnum, col + 1)
      if line[col] =~# '[[({]'
        let open += 1
      elseif open > 0
        let open -= 1
      else
        let last_close = col + 1
      endif
    endif
    let col = match(line, '[[\](){}]', col + 1)
  endwhile
  return [open, last_close]
endfunction

" The line without a trailing comment and whitespace
function s:LastCode(lnum) abort
  let line = getline(a:lnum)
  let col = match(line, '/[/*]')
  while col >= 0
    if synIDattr(synID(a:lnum, col + 1, 1), 'name') =~# 'Comment'
      let line = strpart(line, 0, col)
      break
    endif
    let col = match(line, '/[/*]', col + 1)
  endwhile
  return substitute(line, '\s\+$', '', '')
endfunction

function s:IsCommentLine(lnum) abort
  let col = match(getline(a:lnum), '\S') + 1
  return col > 0 && synIDattr(synID(a:lnum, col, 1), 'name') =~# 'Comment'
endfunction

" The previous line that isn't blank or a comment
function s:PrevCode(lnum) abort
  let lnum = prevnonblank(a:lnum - 1)
  while lnum > 0 && s:IsCommentLine(lnum) && !s:StartsInRegion(lnum)
    let lnum = prevnonblank(lnum - 1)
  endwhile
  return lnum
endfunction

" Whether the expression of the line continues on the next line. Returns
" 'let' after the bindings of a let expression, 1 after an operator, '->',
" 'else' or the condition of an if expression, and 0 otherwise.
function s:Continues(lnum) abort
  let code = s:LastCode(a:lnum)
  if code ==# '' || s:IsText(a:lnum, len(code))
    return 0
  endif
  " Binary operators, but not the '>' of type arguments
  if code =~# '\%(=\|->\|&&\|||\|??\||>\|[-+*/%<>|]\|\<else\|\<is\|\<as\)$'
        \ && synIDattr(synID(a:lnum, len(code), 1), 'name') !=# 'pklBrackets'
    return 1
  endif
  if code =~# ')$'
    let save = getcurpos()
    call cursor(a:lnum, len(code))
    let [lnum, col] = searchpairpos('(', '', ')', 'bnW', s:skip)
    call setpos('.', save)
    if lnum > 0
      let before = strpart(getline(lnum), 0, col - 1)
      if before =~# '\<let\s*$'
        return 'let'
      elseif before =~# '\<if\s*$'
        return 1
      endif
    endif
  endif
  return 0
endfunction

" Lines that continue the expression of the line before
let s:continuation = '^\s*\%(\.\|?\.\||\|&&\|||\|??\||>\|->\|else\>\)'

" Whether the line continues the expression of the previous line
function s:IsContinuation(lnum) abort
  let prev = s:PrevCode(a:lnum)
  if prev == 0 || s:Brackets(prev)[0] > 0
    return 0
  endif
  return getline(a:lnum) =~# s:continuation || s:Continues(prev) isnot 0
endfunction

" The first line of the expression the given line belongs to. Skips over
" multiline strings, bracket groups that span multiple lines and lines that
" continue an expression.
function s:ExpressionStart(lnum) abort
  let lnum = a:lnum
  while lnum > 1
    let lnum = s:RegionStart(lnum)
    let col = matchend(getline(lnum), '^\s*[\])}]')
    if col <= 0
      let col = s:Brackets(lnum)[1]
    endif
    if col > 0
      let opening = s:OpeningLine(lnum, col)
      if opening > 0 && opening < lnum
        let lnum = opening
        continue
      endif
    endif
    if !s:IsContinuation(lnum)
      break
    endif
    let lnum = s:PrevCode(lnum)
  endwhile
  return lnum
endfunction

" The line of the 'if' that belongs to the 'else' at the given line
function s:IfLine(lnum) abort
  let save = getcurpos()
  call cursor(a:lnum, 1)
  let lnum = searchpair('\<if\>', '', '\<else\>', 'bnW', s:skip)
  call setpos('.', save)
  return lnum
endfunction

function GetPklIndent(lnum) abort
  let prev = prevnonblank(a:lnum - 1)
  if prev == 0
    return 0
  endif
  let line = getline(a:lnum)
  let sw = shiftwidth()

  " Text in multiline strings and block comments keeps its indentation. The
  " first line of a string is indented, when it is typed.
  if s:StartsInRegion(a:lnum)
    if line =~# '^\s*$' && !s:StartsInRegion(prev) && getline(prev) =~# '"""#*$'
      return indent(prev) + sw
    endif
    return -1
  endif

  " A closing bracket is aligned with the line of the opening bracket
  let col = matchend(line, '^\s*[\])}]')
  if col > 0
    let lnum = s:OpeningLine(a:lnum, col)
    return lnum > 0 ? indent(s:RegionStart(lnum)) : indent(prev)
  endif

  " 'else' is aligned with its 'if'
  if line =~# '^\s*else\>'
    let lnum = s:IfLine(a:lnum)
    return lnum > 0 ? indent(lnum) : indent(prev)
  endif

  let prev = s:PrevCode(a:lnum)
  if prev == 0
    return 0
  endif
  let base = s:RegionStart(prev)

  " The first line in an object, class, list or argument list
  if s:Brackets(prev)[0] > 0
    return indent(base) + sw
  endif

  " The expression continues after '=', '->', an operator, 'else' or the
  " condition of an if expression. Multiple let expressions are aligned.
  let continues = s:Continues(prev)
  if continues is# 'let' && line =~# '^\s*let\>'
    return indent(base)
  elseif continues isnot 0
    return indent(base) + sw
  endif

  " Method chains and union types
  if line =~# s:continuation
    let lnum = base
    let col = matchend(getline(lnum), '^\s*[\])}]')
    if col <= 0
      let col = s:Brackets(lnum)[1]
    endif
    if col > 0
      let lnum = s:RegionStart(max([1, s:OpeningLine(lnum, col)]))
    endif
    if getline(lnum) =~# s:continuation || (line =~# '^\s*|' && s:IsContinuation(lnum))
      return indent(lnum)
    endif
    return indent(lnum) + sw
  endif

  " A new member or element
  return indent(s:ExpressionStart(prev))
endfunction

let &cpo = s:cpo_save
unlet s:cpo_save
