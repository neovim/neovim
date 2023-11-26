" Vim indent file
" Language:             Scala (http://scala-lang.org/)
" Original Author:      Stefan Matthias Aust
" Modifications By:     Derek Wyatt
" URL:                  https://github.com/derekwyatt/vim-scala
" Last Change:          2016 Aug 26
"                       2023 Aug 28 by Vim Project (undo_indent)

if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal autoindent
setlocal indentexpr=GetScalaIndent()
setlocal indentkeys=0{,0},0),!^F,<>>,o,O,e,=case,<CR>

let b:undo_indent = "setl ai< inde< indk<"

if exists("*GetScalaIndent")
  finish
endif
let s:keepcpo= &cpo
set cpo&vim

let s:annotationMatcher = '@[A-Za-z._]\+\s\+'
let s:modifierMatcher = s:annotationMatcher . '\|\%(private\|protected\)\%(\[[^\]]*\]\)\?\s\+\|abstract\s\+\|override\s\+\|final\s\+'
let s:defMatcher = '\%(' . s:modifierMatcher . '\)*\<def\>'
let s:valMatcher = '\%(' . s:modifierMatcher . '\|lazy\s\+\)*\<va[lr]\>'
let s:funcNameMatcher = '\w\+'
let s:typeSpecMatcher = '\%(\s*\[\_[^\]]*\]\)'
let s:defArgMatcher = '\%((\_.\{-})\)'
let s:returnTypeMatcher = '\%(:\s*\w\+' . s:typeSpecMatcher . '\?\)'
let g:fullDefMatcher = '^\s*' . s:defMatcher . '\s\+' . s:funcNameMatcher . '\s*' . s:typeSpecMatcher . '\?\s*' . s:defArgMatcher . '\?\s*' . s:returnTypeMatcher . '\?\s*[={]'

function! scala#ConditionalConfirm(msg)
  if 0
    call confirm(a:msg)
  endif
endfunction

function! scala#GetLine(lnum)
  let line = substitute(getline(a:lnum), '//.*$', '', '')
  let line = substitute(line, '"\(.\|\\"\)\{-}"', '""', 'g')
  return line
endfunction

function! scala#CountBrackets(line, openBracket, closedBracket)
  let line = substitute(a:line, '"\(.\|\\"\)\{-}"', '', 'g')
  let open = substitute(line, '[^' . a:openBracket . ']', '', 'g')
  let close = substitute(line, '[^' . a:closedBracket . ']', '', 'g')
  return strlen(open) - strlen(close)
endfunction

function! scala#CountParens(line)
  return scala#CountBrackets(a:line, '(', ')')
endfunction

function! scala#CountCurlies(line)
  return scala#CountBrackets(a:line, '{', '}')
endfunction

function! scala#LineEndsInIncomplete(line)
  if a:line =~ '[.,]\s*$'
    return 1
  else
    return 0
  endif
endfunction

function! scala#LineIsAClosingXML(line)
  if a:line =~ '^\s*</\w'
    return 1
  else
    return 0
  endif
endfunction

function! scala#LineCompletesXML(lnum, line)
  let savedpos = getpos('.')
  call setpos('.', [savedpos[0], a:lnum, 0, savedpos[3]])
  let tag = substitute(a:line, '^.*</\([^>]*\)>.*$', '\1', '')
  let [lineNum, colnum] = searchpairpos('<' . tag . '>', '', '</' . tag . '>', 'Wbn')
  call setpos('.', savedpos)
  let pline = scala#GetLine(prevnonblank(lineNum - 1))
  if pline =~ '=\s*$'
    return 1
  else
    return 0
  endif
endfunction

function! scala#IsParentCase()
  let savedpos = getpos('.')
  call setpos('.', [savedpos[0], savedpos[1], 0, savedpos[3]])
  let [l, c] = searchpos('^\s*\%(' . s:defMatcher . '\|\%(\<case\>\)\)', 'bnW')
  let retvalue = -1
  if l != 0 && search('\%' . l . 'l\s*\<case\>', 'bnW')
    let retvalue = l
  endif
  call setpos('.', savedpos)
  return retvalue
endfunction

function! scala#CurlyMatcher()
  let matchline = scala#GetLineThatMatchesBracket('{', '}')
  if scala#CountParens(scala#GetLine(matchline)) < 0
    let savedpos = getpos('.')
    call setpos('.', [savedpos[0], matchline, 9999, savedpos[3]])
    call searchpos('{', 'Wbc')
    call searchpos(')', 'Wb')
    let [lnum, colnum] = searchpairpos('(', '', ')', 'Wbn')
    call setpos('.', savedpos)
    let line = scala#GetLine(lnum)
    if line =~ '^\s*' . s:defMatcher
      return lnum
    else
      return matchline
    endif
  else
    return matchline
  endif
endfunction

function! scala#GetLineAndColumnThatMatchesCurly()
  return scala#GetLineAndColumnThatMatchesBracket('{', '}')
endfunction

function! scala#GetLineAndColumnThatMatchesParen()
  return scala#GetLineAndColumnThatMatchesBracket('(', ')')
endfunction

function! scala#GetLineAndColumnThatMatchesBracket(openBracket, closedBracket)
  let savedpos = getpos('.')
  let curline = scala#GetLine(line('.'))
  if curline =~ a:closedBracket . '.*' . a:openBracket . '.*' . a:closedBracket
    call setpos('.', [savedpos[0], savedpos[1], 0, savedpos[3]])
    call searchpos(a:closedBracket . '\ze[^' . a:closedBracket . a:openBracket . ']*' . a:openBracket, 'W')
  else
    call setpos('.', [savedpos[0], savedpos[1], 9999, savedpos[3]])
    call searchpos(a:closedBracket, 'Wbc')
  endif
  let [lnum, colnum] = searchpairpos(a:openBracket, '', a:closedBracket, 'Wbn')
  call setpos('.', savedpos)
  return [lnum, colnum]
endfunction

function! scala#GetLineThatMatchesCurly()
  return scala#GetLineThatMatchesBracket('{', '}')
endfunction

function! scala#GetLineThatMatchesParen()
  return scala#GetLineThatMatchesBracket('(', ')')
endfunction

function! scala#GetLineThatMatchesBracket(openBracket, closedBracket)
  let [lnum, colnum] = scala#GetLineAndColumnThatMatchesBracket(a:openBracket, a:closedBracket)
  return lnum
endfunction

function! scala#NumberOfBraceGroups(line)
  let line = substitute(a:line, '[^()]', '', 'g')
  if strlen(line) == 0
    return 0
  endif
  let line = substitute(line, '^)*', '', 'g')
  if strlen(line) == 0
    return 0
  endif
  let line = substitute(line, '^(', '', 'g')
  if strlen(line) == 0
    return 0
  endif
  let c = 1
  let counter = 0
  let groupCount = 0
  while counter < strlen(line)
    let char = strpart(line, counter, 1)
    if char == '('
      let c = c + 1
    elseif char == ')'
      let c = c - 1
    endif
    if c == 0
      let groupCount = groupCount + 1
    endif
    let counter = counter + 1
  endwhile
  return groupCount
endfunction

function! scala#MatchesIncompleteDefValr(line)
  if a:line =~ '^\s*\%(' . s:defMatcher . '\|' . s:valMatcher . '\).*[=({]\s*$'
    return 1
  else
    return 0
  endif
endfunction

function! scala#LineIsCompleteIf(line)
  if scala#CountBrackets(a:line, '{', '}') == 0 &&
   \ scala#CountBrackets(a:line, '(', ')') == 0 &&
   \ a:line =~ '^\s*\<if\>\s*([^)]*)\s*\S.*$'
    return 1
  else
    return 0
  endif
endfunction

function! scala#LineCompletesIfElse(lnum, line)
  if a:line =~ '^\s*\%(\<if\>\|\%(}\s*\)\?\<else\>\)'
    return 0
  endif
  let result = search('^\%(\s*\<if\>\s*(.*).*\n\|\s*\<if\>\s*(.*)\s*\n.*\n\)\%(\s*\<else\>\s*\<if\>\s*(.*)\s*\n.*\n\)*\%(\s*\<else\>\s*\n\|\s*\<else\>[^{]*\n\)\?\%' . a:lnum . 'l', 'Wbn')
  if result != 0 && scala#GetLine(prevnonblank(a:lnum - 1)) !~ '{\s*$'
    return result
  endif
  return 0
endfunction

function! scala#GetPrevCodeLine(lnum)
  " This needs to skip comment lines
  return prevnonblank(a:lnum - 1)
endfunction

function! scala#InvertBracketType(openBracket, closedBracket)
  if a:openBracket == '('
    return [ '{', '}' ]
  else
    return [ '(', ')' ]
  endif
endfunction

function! scala#Testhelper(lnum, line, openBracket, closedBracket, iteration)
  let bracketCount = scala#CountBrackets(a:line, a:openBracket, a:closedBracket)
  " There are more '}' braces than '{' on this line so it may be completing the function definition
  if bracketCount < 0
    let [matchedLNum, matchedColNum] = scala#GetLineAndColumnThatMatchesBracket(a:openBracket, a:closedBracket)
    if matchedLNum == a:lnum
      return -1
    endif
    let matchedLine = scala#GetLine(matchedLNum)
    if ! scala#MatchesIncompleteDefValr(matchedLine)
      let bracketLine = substitute(substitute(matchedLine, '\%' . matchedColNum . 'c.*$', '', ''), '[^{}()]', '', 'g')
      if bracketLine =~ '}$'
        return scala#Testhelper(matchedLNum, matchedLine, '{', '}', a:iteration + 1)
      elseif bracketLine =~ ')$'
        return scala#Testhelper(matchedLNum, matchedLine, '(', ')', a:iteration + 1)
      else
        let prevCodeLNum = scala#GetPrevCodeLine(matchedLNum)
        if scala#MatchesIncompleteDefValr(scala#GetLine(prevCodeLNum))
          return prevCodeLNum
        else
          return -1
        endif
      endif
    else
      " return indent value instead
      return matchedLNum
    endif
  " There's an equal number of '{' and '}' on this line so it may be a single line function definition
  elseif bracketCount == 0
    if a:iteration == 0
      let otherBracketType = scala#InvertBracketType(a:openBracket, a:closedBracket)
      return scala#Testhelper(a:lnum, a:line, otherBracketType[0], otherBracketType[1], a:iteration + 1)
    else
      let prevCodeLNum = scala#GetPrevCodeLine(a:lnum)
      let prevCodeLine = scala#GetLine(prevCodeLNum)
      if scala#MatchesIncompleteDefValr(prevCodeLine) && prevCodeLine !~ '{\s*$'
        return prevCodeLNum
      else
        let possibleIfElse = scala#LineCompletesIfElse(a:lnum, a:line)
        if possibleIfElse != 0
          let defValrLine = prevnonblank(possibleIfElse - 1)
          let possibleDefValr = scala#GetLine(defValrLine)
          if scala#MatchesIncompleteDefValr(possibleDefValr) && possibleDefValr =~ '^.*=\s*$'
            return possibleDefValr
          else
            return -1
          endif
        else
          return -1
        endif
      endif
    endif
  else
    return -1
  endif
endfunction

function! scala#Test(lnum, line, openBracket, closedBracket)
  return scala#Testhelper(a:lnum, a:line, a:openBracket, a:closedBracket, 0)
endfunction

function! scala#LineCompletesDefValr(lnum, line)
  let bracketCount = scala#CountBrackets(a:line, '{', '}')
  if bracketCount < 0
    let matchedBracket = scala#GetLineThatMatchesBracket('{', '}')
    if ! scala#MatchesIncompleteDefValr(scala#GetLine(matchedBracket))
      let possibleDefValr = scala#GetLine(prevnonblank(matchedBracket - 1))
      if matchedBracket != -1 && scala#MatchesIncompleteDefValr(possibleDefValr)
        return 1
      else
        return 0
      endif
    else
      return 0
    endif
  elseif bracketCount == 0
    let bracketCount = scala#CountBrackets(a:line, '(', ')')
    if bracketCount < 0
      let matchedBracket = scala#GetLineThatMatchesBracket('(', ')')
      if ! scala#MatchesIncompleteDefValr(scala#GetLine(matchedBracket))
        let possibleDefValr = scala#GetLine(prevnonblank(matchedBracket - 1))
        if matchedBracket != -1 && scala#MatchesIncompleteDefValr(possibleDefValr)
          return 1
        else
          return 0
        endif
      else
        return 0
      endif
    elseif bracketCount == 0
      let possibleDefValr = scala#GetLine(prevnonblank(a:lnum - 1))
      if scala#MatchesIncompleteDefValr(possibleDefValr) && possibleDefValr =~ '^.*=\s*$'
        return 1
      else
        let possibleIfElse = scala#LineCompletesIfElse(a:lnum, a:line)
        if possibleIfElse != 0
          let possibleDefValr = scala#GetLine(prevnonblank(possibleIfElse - 1))
          if scala#MatchesIncompleteDefValr(possibleDefValr) && possibleDefValr =~ '^.*=\s*$'
            return 2
          else
            return 0
          endif
        else
          return 0
        endif
      endif
    else
      return 0
    endif
  endif
endfunction

function! scala#SpecificLineCompletesBrackets(lnum, openBracket, closedBracket)
  let savedpos = getpos('.')
  call setpos('.', [savedpos[0], a:lnum, 9999, savedpos[3]])
  let retv = scala#LineCompletesBrackets(a:openBracket, a:closedBracket)
  call setpos('.', savedpos)

  return retv
endfunction

function! scala#LineCompletesBrackets(openBracket, closedBracket)
  let savedpos = getpos('.')
  let offline = 0
  while offline == 0
    let [lnum, colnum] = searchpos(a:closedBracket, 'Wb')
    let [lnumA, colnumA] = searchpairpos(a:openBracket, '', a:closedBracket, 'Wbn')
    if lnum != lnumA
      let [lnumB, colnumB] = searchpairpos(a:openBracket, '', a:closedBracket, 'Wbnr')
      let offline = 1
    endif
  endwhile
  call setpos('.', savedpos)
  if lnumA == lnumB && colnumA == colnumB
    return lnumA
  else
    return -1
  endif
endfunction

function! GetScalaIndent()
  " Find a non-blank line above the current line.
  let prevlnum = prevnonblank(v:lnum - 1)

  " Hit the start of the file, use zero indent.
  if prevlnum == 0
    return 0
  endif

  let ind = indent(prevlnum)
  let originalIndentValue = ind
  let prevline = scala#GetLine(prevlnum)
  let curlnum = v:lnum
  let curline = scala#GetLine(curlnum)
  if get(g:, 'scala_scaladoc_indent', 0)
    let star_indent = 2
  else
    let star_indent = 1
  end

  if prevline =~ '^\s*/\*\*'
    if prevline =~ '\*/\s*$'
      return ind
    else
      return ind + star_indent
    endif
  endif

  if curline =~ '^\s*\*'
    return cindent(curlnum)
  endif

  " If this line starts with a { then make it indent the same as the previous line
  if curline =~ '^\s*{'
    call scala#ConditionalConfirm("1")
    " Unless, of course, the previous one is a { as well
    if prevline !~ '^\s*{'
      call scala#ConditionalConfirm("2")
      return indent(prevlnum)
    endif
  endif

  " '.' continuations
  if curline =~ '^\s*\.'
    if prevline =~ '^\s*\.'
      return ind
    else
      return ind + shiftwidth()
    endif
  endif

  " Indent html literals
  if prevline !~ '/>\s*$' && prevline =~ '^\s*<[a-zA-Z][^>]*>\s*$'
    call scala#ConditionalConfirm("3")
    return ind + shiftwidth()
  endif

  " assumes curly braces around try-block
  if curline =~ '^\s*}\s*\<catch\>'
    return ind - shiftwidth()
  elseif curline =~ '^\s*\<catch\>'
    return ind
  endif

  " Add a shiftwidth()' after lines that start a block
  " If 'if', 'for' or 'while' end with ), this is a one-line block
  " If 'val', 'var', 'def' end with =, this is a one-line block
  if (prevline =~ '^\s*\<\%(\%(}\?\s*else\s\+\)\?if\|for\|while\)\>.*[)=]\s*$' && scala#NumberOfBraceGroups(prevline) <= 1)
        \ || prevline =~ '^\s*' . s:defMatcher . '.*=\s*$'
        \ || prevline =~ '^\s*' . s:valMatcher . '.*[=]\s*$'
        \ || prevline =~ '^\s*\%(}\s*\)\?\<else\>\s*$'
        \ || prevline =~ '=\s*$'
    call scala#ConditionalConfirm("4")
    let ind = ind + shiftwidth()
  elseif prevline =~ '^\s*\<\%(}\?\s*else\s\+\)\?if\>' && curline =~ '^\s*}\?\s*\<else\>'
    return ind
  endif

  let lineCompletedBrackets = 0
  let bracketCount = scala#CountBrackets(prevline, '{', '}')
  if bracketCount > 0 || prevline =~ '.*{\s*$'
    call scala#ConditionalConfirm("5b")
    let ind = ind + shiftwidth()
  elseif bracketCount < 0
    call scala#ConditionalConfirm("6b")
    " if the closing brace actually completes the braces entirely, then we
    " have to indent to line that started the whole thing
    let completeLine = scala#LineCompletesBrackets('{', '}')
    if completeLine != -1
      call scala#ConditionalConfirm("8b")
      let prevCompleteLine = scala#GetLine(prevnonblank(completeLine - 1))
      " However, what actually started this part looks like it was a function
      " definition, so we need to indent to that line instead.  This is
      " actually pretty weak at the moment.
      if prevCompleteLine =~ '=\s*$'
        call scala#ConditionalConfirm("9b")
        let ind = indent(prevnonblank(completeLine - 1))
      else
        call scala#ConditionalConfirm("10b")
        let ind = indent(completeLine)
      endif
    else
      let lineCompletedBrackets = 1
    endif
  endif

  if ind == originalIndentValue
    let bracketCount = scala#CountBrackets(prevline, '(', ')')
    if bracketCount > 0 || prevline =~ '.*(\s*$'
      call scala#ConditionalConfirm("5a")
      let ind = ind + shiftwidth()
    elseif bracketCount < 0
      call scala#ConditionalConfirm("6a")
      " if the closing brace actually completes the braces entirely, then we
      " have to indent to line that started the whole thing
      let completeLine = scala#LineCompletesBrackets('(', ')')
      if completeLine != -1 && prevline !~ '^.*{\s*$'
        call scala#ConditionalConfirm("8a")
        let prevCompleteLine = scala#GetLine(prevnonblank(completeLine - 1))
        " However, what actually started this part looks like it was a function
        " definition, so we need to indent to that line instead.  This is
        " actually pretty weak at the moment.
        if prevCompleteLine =~ '=\s*$'
          call scala#ConditionalConfirm("9a")
          let ind = indent(prevnonblank(completeLine - 1))
        else
          call scala#ConditionalConfirm("10a")
          let ind = indent(completeLine)
        endif
      else
        " This is the only part that's different from from the '{', '}' one below
        " Yup... some refactoring is necessary at some point.
        let ind = ind + (bracketCount * shiftwidth())
        let lineCompletedBrackets = 1
      endif
    endif
  endif

  if curline =~ '^\s*}\?\s*\<else\>\%(\s\+\<if\>\s*(.*)\)\?\s*{\?\s*$' &&
   \ ! scala#LineIsCompleteIf(prevline) &&
   \ prevline !~ '^.*}\s*$'
    let ind = ind - shiftwidth()
  endif

  " Subtract a shiftwidth()' on '}' or html
  let curCurlyCount = scala#CountCurlies(curline)
  if curCurlyCount < 0
    call scala#ConditionalConfirm("14a")
    let matchline = scala#CurlyMatcher()
    return indent(matchline)
  elseif curline =~ '^\s*</[a-zA-Z][^>]*>'
    call scala#ConditionalConfirm("14c")
    return ind - shiftwidth()
  endif

  let prevParenCount = scala#CountParens(prevline)
  if prevline =~ '^\s*\<for\>.*$' && prevParenCount > 0
    call scala#ConditionalConfirm("15")
    let ind = indent(prevlnum) + 5
  endif

  let prevCurlyCount = scala#CountCurlies(prevline)
  if prevCurlyCount == 0 && prevline =~ '^.*\%(=>\|⇒\)\s*$' && prevline !~ '^\s*this\s*:.*\%(=>\|⇒\)\s*$' && curline !~ '^\s*\<case\>'
    call scala#ConditionalConfirm("16")
    let ind = ind + shiftwidth()
  endif

  if ind == originalIndentValue && curline =~ '^\s*\<case\>'
    call scala#ConditionalConfirm("17")
    let parentCase = scala#IsParentCase()
    if parentCase != -1
      call scala#ConditionalConfirm("17a")
      return indent(parentCase)
    endif
  endif

  if prevline =~ '^\s*\*/'
   \ || prevline =~ '*/\s*$'
    call scala#ConditionalConfirm("18")
    let ind = ind - star_indent
  endif

  if scala#LineEndsInIncomplete(prevline)
    call scala#ConditionalConfirm("19")
    return ind
  endif

  if scala#LineIsAClosingXML(prevline)
    if scala#LineCompletesXML(prevlnum, prevline)
      call scala#ConditionalConfirm("20a")
      return ind - shiftwidth()
    else
      call scala#ConditionalConfirm("20b")
      return ind
    endif
  endif

  if ind == originalIndentValue
    "let indentMultiplier = scala#LineCompletesDefValr(prevlnum, prevline)
    "if indentMultiplier != 0
    "  call scala#ConditionalConfirm("19a")
    "  let ind = ind - (indentMultiplier * shiftwidth())
    let defValrLine = scala#Test(prevlnum, prevline, '{', '}')
    if defValrLine != -1
      call scala#ConditionalConfirm("21a")
      let ind = indent(defValrLine)
    elseif lineCompletedBrackets == 0
      call scala#ConditionalConfirm("21b")
      if scala#GetLine(prevnonblank(prevlnum - 1)) =~ '^.*\<else\>\s*\%(//.*\)\?$'
        call scala#ConditionalConfirm("21c")
        let ind = ind - shiftwidth()
      elseif scala#LineCompletesIfElse(prevlnum, prevline)
        call scala#ConditionalConfirm("21d")
        let ind = ind - shiftwidth()
      elseif scala#CountParens(curline) < 0 && curline =~ '^\s*)' && scala#GetLine(scala#GetLineThatMatchesBracket('(', ')')) =~ '.*(\s*$'
        " Handles situations that look like this:
        "
        "   val a = func(
        "     10
        "   )
        "
        " or
        "
        "   val a = func(
        "     10
        "   ).somethingHere()
        call scala#ConditionalConfirm("21e")
        let ind = ind - shiftwidth()
      endif
    endif
  endif

  call scala#ConditionalConfirm("returning " . ind)

  return ind
endfunction

let &cpo = s:keepcpo
unlet s:keepcpo

" vim:set sw=2 sts=2 ts=8 et:
" vim600:fdm=marker fdl=1 fdc=0:
