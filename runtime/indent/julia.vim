" Vim indent file
" Language:	Julia
" Maintainer:	Carlo Baldassi <carlobaldassi@gmail.com>
" Homepage:	https://github.com/JuliaEditorSupport/julia-vim
" Last Change:	2022 Jun 14
"		2023 Aug 28 by Vim Project (undo_indent)
" Notes:        originally based on Bram Moolenaar's indent file for vim

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal autoindent

setlocal indentexpr=GetJuliaIndent()
setlocal indentkeys+==end,=else,=catch,=finally,),],}
setlocal indentkeys-=0#
setlocal indentkeys-=:
setlocal indentkeys-=0{
setlocal indentkeys-=0}
setlocal nosmartindent

let b:undo_indent = "setl ai< inde< indk< si<"

" Only define the function once.
if exists("*GetJuliaIndent")
  finish
endif

let s:skipPatternsBasic = '\<julia\%(Comment\%([LM]\|Delim\)\)\>'
let s:skipPatterns = '\<julia\%(Comprehension\%(For\|If\)\|RangeKeyword\|Comment\%([LM]\|Delim\)\|\%([bs]\|Shell\|Printf\|Doc\)\?String\|StringPrefixed\|DocStringM\(Raw\)\?\|RegEx\|SymbolS\?\|Macro\|Dotted\)\>'

function JuliaMatch(lnum, str, regex, st, ...)
  let s = a:st
  let e = a:0 > 0 ? a:1 : -1
  let basic_skip = a:0 > 1 ? a:2 : 'all'
  let skip = basic_skip ==# 'basic' ? s:skipPatternsBasic : s:skipPatterns
  while 1
    let f = match(a:str, '\C' . a:regex, s)
    if e >= 0 && f >= e
      return -1
    endif
    if f >= 0
      let attr = synIDattr(synID(a:lnum,f+1,1),"name")
      let attrT = synIDattr(synID(a:lnum,f+1,0),"name")
      if attr =~# skip || attrT =~# skip
        let s = f+1
        continue
      endif
    endif
    break
  endwhile
  return f
endfunction

function GetJuliaNestingStruct(lnum, ...)
  " Auxiliary function to inspect the block structure of a line
  let line = getline(a:lnum)
  let s = a:0 > 0 ? a:1 : 0
  let e = a:0 > 1 ? a:2 : -1
  let blocks_stack = []
  let num_closed_blocks = 0
  while 1
    let fb = JuliaMatch(a:lnum, line, '\<\%(if\|else\%(if\)\?\|while\|for\|try\|catch\|finally\|\%(staged\)\?function\|macro\|begin\|mutable\s\+struct\|\%(mutable\s\+\)\@<!struct\|\%(abstract\|primitive\)\s\+type\|let\|\%(bare\)\?module\|quote\|do\)\>', s, e)
    let fe = JuliaMatch(a:lnum, line, '\<end\>', s, e)

    if fb < 0 && fe < 0
      " No blocks found
      break
    end

    if fb >= 0 && (fb < fe || fe < 0)
      " The first occurrence is an opening block keyword
      " Note: some keywords (elseif,else,catch,finally) are both
      "       closing blocks and opening new ones

      let i = JuliaMatch(a:lnum, line, '\<if\>', s)
      if i >= 0 && i == fb
        let s = i+1
        call add(blocks_stack, 'if')
        continue
      endif
      let i = JuliaMatch(a:lnum, line, '\<elseif\>', s)
      if i >= 0 && i == fb
        let s = i+1
        if len(blocks_stack) > 0 && blocks_stack[-1] == 'if'
          let blocks_stack[-1] = 'elseif'
        elseif (len(blocks_stack) > 0 && blocks_stack[-1] != 'elseif') || len(blocks_stack) == 0
          call add(blocks_stack, 'elseif')
          let num_closed_blocks += 1
        endif
        continue
      endif
      let i = JuliaMatch(a:lnum, line, '\<else\>', s)
      if i >= 0 && i == fb
        let s = i+1
        if len(blocks_stack) > 0 && blocks_stack[-1] =~# '\<\%(else\)\=if\>'
          let blocks_stack[-1] = 'else'
        else
          call add(blocks_stack, 'else')
          let num_closed_blocks += 1
        endif
        continue
      endif

      let i = JuliaMatch(a:lnum, line, '\<try\>', s)
      if i >= 0 && i == fb
        let s = i+1
        call add(blocks_stack, 'try')
        continue
      endif
      let i = JuliaMatch(a:lnum, line, '\<catch\>', s)
      if i >= 0 && i == fb
        let s = i+1
        if len(blocks_stack) > 0 && blocks_stack[-1] == 'try'
          let blocks_stack[-1] = 'catch'
        else
          call add(blocks_stack, 'catch')
          let num_closed_blocks += 1
        endif
        continue
      endif
      let i = JuliaMatch(a:lnum, line, '\<finally\>', s)
      if i >= 0 && i == fb
        let s = i+1
        if len(blocks_stack) > 0 && (blocks_stack[-1] == 'try' || blocks_stack[-1] == 'catch')
          let blocks_stack[-1] = 'finally'
        else
          call add(blocks_stack, 'finally')
          let num_closed_blocks += 1
        endif
        continue
      endif

      let i = JuliaMatch(a:lnum, line, '\<\%(bare\)\?module\>', s)
      if i >= 0 && i == fb
        let s = i+1
        if i == 0
          call add(blocks_stack, 'col1module')
        else
          call add(blocks_stack, 'other')
        endif
        continue
      endif

      let i = JuliaMatch(a:lnum, line, '\<\%(while\|for\|function\|macro\|begin\|\%(mutable\s\+\)\?struct\|\%(abstract\|primitive\)\s\+type\|let\|quote\|do\)\>', s)
      if i >= 0 && i == fb
        if match(line, '\C\<\%(mutable\|abstract\|primitive\)', i) != -1
          let s = i+11
        else
          let s = i+1
        endif
        call add(blocks_stack, 'other')
        continue
      endif

      " Note: it should be impossible to get here
      break

    else
      " The first occurrence is an 'end'

      let s = fe+1
      if len(blocks_stack) == 0
        let num_closed_blocks += 1
      else
        call remove(blocks_stack, -1)
      endif
      continue

    endif

    " Note: it should be impossible to get here
    break
  endwhile
  let num_open_blocks = len(blocks_stack) - count(blocks_stack, 'col1module')
  return [num_open_blocks, num_closed_blocks]
endfunction

function GetJuliaNestingBrackets(lnum, c)
  " Auxiliary function to inspect the brackets structure of a line
  let line = getline(a:lnum)[0 : (a:c - 1)]
  let s = 0
  let brackets_stack = []
  let last_closed_bracket = -1
  while 1
    let fb = JuliaMatch(a:lnum, line, '[([{]', s)
    let fe = JuliaMatch(a:lnum, line, '[])}]', s)

    if fb < 0 && fe < 0
      " No brackets found
      break
    end

    if fb >= 0 && (fb < fe || fe < 0)
      " The first occurrence is an opening bracket

      let i = JuliaMatch(a:lnum, line, '(', s)
      if i >= 0 && i == fb
        let s = i+1
        call add(brackets_stack, ['par',i])
        continue
      endif

      let i = JuliaMatch(a:lnum, line, '\[', s)
      if i >= 0 && i == fb
        let s = i+1
        call add(brackets_stack, ['sqbra',i])
        continue
      endif

      let i = JuliaMatch(a:lnum, line, '{', s)
      if i >= 0 && i == fb
        let s = i+1
        call add(brackets_stack, ['curbra',i])
        continue
      endif

      " Note: it should be impossible to get here
      break

    else
      " The first occurrence is a closing bracket

      let i = JuliaMatch(a:lnum, line, ')', s)
      if i >= 0 && i == fe
        let s = i+1
        if len(brackets_stack) > 0 && brackets_stack[-1][0] == 'par'
          call remove(brackets_stack, -1)
        else
          let last_closed_bracket = i + 1
        endif
        continue
      endif

      let i = JuliaMatch(a:lnum, line, ']', s)
      if i >= 0 && i == fe
        let s = i+1
        if len(brackets_stack) > 0 && brackets_stack[-1][0] == 'sqbra'
          call remove(brackets_stack, -1)
        else
          let last_closed_bracket = i + 1
        endif
        continue
      endif

      let i = JuliaMatch(a:lnum, line, '}', s)
      if i >= 0 && i == fe
        let s = i+1
        if len(brackets_stack) > 0 && brackets_stack[-1][0] == 'curbra'
          call remove(brackets_stack, -1)
        else
          let last_closed_bracket = i + 1
        endif
        continue
      endif

      " Note: it should be impossible to get here
      break

    endif

    " Note: it should be impossible to get here
    break
  endwhile
  let first_open_bracket = -1
  let last_open_bracket = -1
  let infuncargs = 0
  if len(brackets_stack) > 0
    let first_open_bracket = brackets_stack[0][1]
    let last_open_bracket = brackets_stack[-1][1]
    if brackets_stack[-1][0] == 'par' && IsFunctionArgPar(a:lnum, last_open_bracket+1)
      let infuncargs = 1
    endif
  endif
  return [first_open_bracket, last_open_bracket, last_closed_bracket, infuncargs]
endfunction

let s:bracketBlocks = '\<julia\%(\%(\%(Printf\)\?Par\|SqBra\%(Idx\)\?\|CurBra\)Block\|ParBlockInRange\|StringVars\%(Par\|SqBra\|CurBra\)\|Dollar\%(Par\|SqBra\)\|QuotedParBlockS\?\)\>'

function IsInBrackets(lnum, c)
  let stack = map(synstack(a:lnum, a:c), 'synIDattr(v:val, "name")')
  call filter(stack, 'v:val =~# s:bracketBlocks')
  return len(stack) > 0
endfunction

function IsInDocString(lnum)
  let stack = map(synstack(a:lnum, 1), 'synIDattr(v:val, "name")')
  call filter(stack, 'v:val =~# "\\<juliaDocString\\(Delim\\|M\\\(Raw\\)\\?\\)\\?\\>"')
  return len(stack) > 0
endfunction

function IsInContinuationImportLine(lnum)
  let stack = map(synstack(a:lnum, 1), 'synIDattr(v:val, "name")')
  call filter(stack, 'v:val =~# "\\<juliaImportLine\\>"')
  if len(stack) == 0
    return 0
  endif
  return JuliaMatch(a:lnum, getline(a:lnum), '\<\%(import\|using\|export\)\>', indent(a:lnum)) == -1
endfunction

function IsFunctionArgPar(lnum, c)
  if a:c == 0
    return 0
  endif
  let stack = map(synstack(a:lnum, a:c-1), 'synIDattr(v:val, "name")')
  return len(stack) >= 2 && stack[-2] ==# 'juliaFunctionDef'
endfunction

function JumpToMatch(lnum, last_closed_bracket)
  " we use the % command to skip back (tries to use matchit if possible,
  " otherwise resorts to vim's default, which is buggy but better than
  " nothing)
  call cursor(a:lnum, a:last_closed_bracket)
  let percmap = maparg("%", "n") 
  if exists("g:loaded_matchit") && percmap =~# 'Match\%(it\|_wrapper\)'
    normal %
  else
    normal! %
  end
endfunction

" Auxiliary function to find a line which does not start in the middle of a
" multiline bracketed expression, to be used as reference for block
" indentation.
function LastBlockIndent(lnum)
  let lnum = a:lnum
  let ind = 0
  while lnum > 0
    let ind = indent(lnum)
    if ind == 0
      return [lnum, 0]
    endif
    if !IsInBrackets(lnum, 1)
      break
    endif
    let lnum = prevnonblank(lnum - 1)
  endwhile
  return [max([lnum,1]), ind]
endfunction

function GetJuliaIndent()
  " Do not alter doctrings indentation
  if IsInDocString(v:lnum)
    return -1
  endif

  " Find a non-blank line above the current line.
  let lnum = prevnonblank(v:lnum - 1)

  " At the start of the file use zero indent.
  if lnum == 0
    return 0
  endif

  let ind = -1
  let st = -1
  let lim = -1

  " Multiline bracketed expressions take precedence
  let align_brackets = get(g:, "julia_indent_align_brackets", 1)
  let align_funcargs = get(g:, "julia_indent_align_funcargs", 0)
  let c = len(getline(lnum)) + 1
  while IsInBrackets(lnum, c)
    let [first_open_bracket, last_open_bracket, last_closed_bracket, infuncargs] = GetJuliaNestingBrackets(lnum, c)

    " First scenario: the previous line has a hanging open bracket:
    " set the indentation to match the opening bracket (plus an extra space)
    " unless we're in a function arguments list or alignment is disabled, in
    " which case we just add an extra indent
    if last_open_bracket != -1
      if (!infuncargs && align_brackets) || (infuncargs && align_funcargs)
        let st = last_open_bracket
        let ind = virtcol([lnum, st + 1])
      else
        let ind = indent(lnum) + shiftwidth()
      endif

    " Second scenario: some multiline bracketed expression was closed in the
    " previous line. But since we know we are still in a bracketed expression,
    " we need to find the line where the bracket was opened
    elseif last_closed_bracket != -1
      call JumpToMatch(lnum, last_closed_bracket)
      if line(".") == lnum
        " something wrong here, give up
        let ind = indent(lnum)
      else
        let lnum = line(".")
        let c = col(".") - 1
        if c == 0
          " uhm, give up
          let ind = 0
        else
          " we skipped a bracket set, keep searching for an opening bracket
          let lim = c
          continue
        endif
      endif

    " Third scenario: nothing special: keep the indentation
    else
      let ind = indent(lnum)
    endif

    " Does the current line start with a closing bracket? Then depending on
    " the situation we align it with the opening one, or we let the rest of
    " the code figure it out (the case in which we're closing a function
    " argument list is special-cased)
    if JuliaMatch(v:lnum, getline(v:lnum), '[])}]', indent(v:lnum)) == indent(v:lnum) && ind > 0
      if !align_brackets && !align_funcargs
        call JumpToMatch(v:lnum, indent(v:lnum))
        return indent(line("."))
      elseif (align_brackets && getline(v:lnum)[indent(v:lnum)] != ')') || align_funcargs
        return ind - 1
      else " must be a ')' and align_brackets==1 and align_funcargs==0
        call JumpToMatch(v:lnum, indent(v:lnum))
        if IsFunctionArgPar(line("."), col("."))
          let ind = -1
        else
          return ind - 1
        endif
      endif
    endif

    break
  endwhile

  if ind == -1
    " We are not in a multiline bracketed expression. Thus we look for a
    " previous line to use as a reference
    let [lnum,ind] = LastBlockIndent(lnum)
    let c = len(getline(lnum)) + 1
    if IsInBrackets(lnum, c)
      let [first_open_bracket, last_open_bracket, last_closed_bracket, infuncargs] = GetJuliaNestingBrackets(lnum, c)
      let lim = first_open_bracket
    endif
  end

  " Analyse the reference line
  let [num_open_blocks, num_closed_blocks] = GetJuliaNestingStruct(lnum, st, lim)
  " Increase indentation for each newly opened block in the reference line
  let ind += shiftwidth() * num_open_blocks

  " Analyse the current line
  let [num_open_blocks, num_closed_blocks] = GetJuliaNestingStruct(v:lnum)
  " Decrease indentation for each closed block in the current line
  let ind -= shiftwidth() * num_closed_blocks

  " Additional special case: multiline import/using/export statements

  let prevline = getline(lnum)
  " Are we in a multiline import/using/export statement, right below the
  " opening line?
  if IsInContinuationImportLine(v:lnum) && !IsInContinuationImportLine(lnum)
    if get(g:, 'julia_indent_align_import', 1)
      " if the opening line has a colon followed by non-comments, use it as
      " reference point
      let cind = JuliaMatch(lnum, prevline, ':', indent(lnum), lim)
      if cind >= 0
        let nonwhiteind = JuliaMatch(lnum, prevline, '\S', cind+1, -1, 'basic')
        if nonwhiteind >= 0
          " return match(prevline, '\S', cind+1) " a bit overkill...
          return cind + 2
        endif
      else
        " if the opening line is not a naked import/using/export statement, use
        " it as reference
        let iind = JuliaMatch(lnum, prevline, '\<import\|using\|export\>', indent(lnum), lim)
        if iind >= 0
          " assuming whitespace after using... so no `using(XYZ)` please!
          let nonwhiteind = JuliaMatch(lnum, prevline, '\S', iind+6, -1, 'basic')
          if nonwhiteind >= 0
            return match(prevline, '\S', iind+6)
          endif
        endif
      endif
    endif
    let ind += shiftwidth()

  " Or did we just close a multiline import/using/export statement?
  elseif !IsInContinuationImportLine(v:lnum) && IsInContinuationImportLine(lnum)
    " find the starting line of the statement
    let ilnum = 0
    for iln in range(lnum-1, 1, -1)
      if !IsInContinuationImportLine(iln)
        let ilnum = iln
        break
      endif
    endfor
    if ilnum == 0
      " something went horribly wrong, give up
      let ind = indent(lnum)
    endif
    let ind = indent(ilnum)
  endif

  return ind
endfunction
