" Vim indent file
" Language: TypeScript
" Maintainer: See https://github.com/HerringtonDarkholme/yats.vim
" Last Change: 2019 Oct 18
" Acknowledgement: Based off of vim-ruby maintained by Nikolai Weibull http://vim-ruby.rubyforge.org

" 0. Initialization {{{1
" =================

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal nosmartindent

" Now, set up our indentation expression and keys that trigger it.
setlocal indentexpr=GetTypescriptIndent()
setlocal formatexpr=Fixedgq(v:lnum,v:count)
setlocal indentkeys=0{,0},0),0],0\,,!^F,o,O,e

" Only define the function once.
if exists("*GetTypescriptIndent")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" 1. Variables {{{1
" ============

let s:js_keywords = '^\s*\(break\|case\|catch\|continue\|debugger\|default\|delete\|do\|else\|finally\|for\|function\|if\|in\|instanceof\|new\|return\|switch\|this\|throw\|try\|typeof\|var\|void\|while\|with\)'

" Regex of syntax group names that are or delimit string or are comments.
let s:syng_strcom = 'string\|regex\|comment\c'

" Regex of syntax group names that are strings.
let s:syng_string = 'regex\c'

" Regex of syntax group names that are strings or documentation.
let s:syng_multiline = 'comment\c'

" Regex of syntax group names that are line comment.
let s:syng_linecom = 'linecomment\c'

" Expression used to check whether we should skip a match with searchpair().
let s:skip_expr = "synIDattr(synID(line('.'),col('.'),1),'name') =~ '".s:syng_strcom."'"

let s:line_term = '\s*\%(\%(\/\/\).*\)\=$'

" Regex that defines continuation lines, not including (, {, or [.
let s:continuation_regex = '\%([\\*+/.:]\|\%(<%\)\@<![=-]\|\W[|&?]\|||\|&&\|[^=]=[^=].*,\)' . s:line_term

" Regex that defines continuation lines.
" TODO: this needs to deal with if ...: and so on
let s:msl_regex = s:continuation_regex

let s:one_line_scope_regex = '\<\%(if\|else\|for\|while\)\>[^{;]*' . s:line_term

" Regex that defines blocks.
let s:block_regex = '\%([{[]\)\s*\%(|\%([*@]\=\h\w*,\=\s*\)\%(,\s*[*@]\=\h\w*\)*|\)\=' . s:line_term

let s:var_stmt = '^\s*var'

let s:comma_first = '^\s*,'
let s:comma_last = ',\s*$'

let s:ternary = '^\s\+[?|:]'
let s:ternary_q = '^\s\+?'

" 2. Auxiliary Functions {{{1
" ======================

" Check if the character at lnum:col is inside a string, comment, or is ascii.
function s:IsInStringOrComment(lnum, col)
  return synIDattr(synID(a:lnum, a:col, 1), 'name') =~ s:syng_strcom
endfunction

" Check if the character at lnum:col is inside a string.
function s:IsInString(lnum, col)
  return synIDattr(synID(a:lnum, a:col, 1), 'name') =~ s:syng_string
endfunction

" Check if the character at lnum:col is inside a multi-line comment.
function s:IsInMultilineComment(lnum, col)
  return !s:IsLineComment(a:lnum, a:col) && synIDattr(synID(a:lnum, a:col, 1), 'name') =~ s:syng_multiline
endfunction

" Check if the character at lnum:col is a line comment.
function s:IsLineComment(lnum, col)
  return synIDattr(synID(a:lnum, a:col, 1), 'name') =~ s:syng_linecom
endfunction

" Find line above 'lnum' that isn't empty, in a comment, or in a string.
function s:PrevNonBlankNonString(lnum)
  let in_block = 0
  let lnum = prevnonblank(a:lnum)
  while lnum > 0
    " Go in and out of blocks comments as necessary.
    " If the line isn't empty (with opt. comment) or in a string, end search.
    let line = getline(lnum)
    if line =~ '/\*'
      if in_block
        let in_block = 0
      else
        break
      endif
    elseif !in_block && line =~ '\*/'
      let in_block = 1
    elseif !in_block && line !~ '^\s*\%(//\).*$' && !(s:IsInStringOrComment(lnum, 1) && s:IsInStringOrComment(lnum, strlen(line)))
      break
    endif
    let lnum = prevnonblank(lnum - 1)
  endwhile
  return lnum
endfunction

" Find line above 'lnum' that started the continuation 'lnum' may be part of.
function s:GetMSL(lnum, in_one_line_scope)
  " Start on the line we're at and use its indent.
  let msl = a:lnum
  let lnum = s:PrevNonBlankNonString(a:lnum - 1)
  while lnum > 0
    " If we have a continuation line, or we're in a string, use line as MSL.
    " Otherwise, terminate search as we have found our MSL already.
    let line = getline(lnum)
    let col = match(line, s:msl_regex) + 1
    if (col > 0 && !s:IsInStringOrComment(lnum, col)) || s:IsInString(lnum, strlen(line))
      let msl = lnum
    else
      " Don't use lines that are part of a one line scope as msl unless the
      " flag in_one_line_scope is set to 1
      "
      if a:in_one_line_scope
        break
      end
      let msl_one_line = s:Match(lnum, s:one_line_scope_regex)
      if msl_one_line == 0
        break
      endif
    endif
    let lnum = s:PrevNonBlankNonString(lnum - 1)
  endwhile
  return msl
endfunction

function s:RemoveTrailingComments(content)
  let single = '\/\/\(.*\)\s*$'
  let multi = '\/\*\(.*\)\*\/\s*$'
  return substitute(substitute(a:content, single, '', ''), multi, '', '')
endfunction

" Find if the string is inside var statement (but not the first string)
function s:InMultiVarStatement(lnum)
  let lnum = s:PrevNonBlankNonString(a:lnum - 1)

"  let type = synIDattr(synID(lnum, indent(lnum) + 1, 0), 'name')

  " loop through previous expressions to find a var statement
  while lnum > 0
    let line = getline(lnum)

    " if the line is a js keyword
    if (line =~ s:js_keywords)
      " check if the line is a var stmt
      " if the line has a comma first or comma last then we can assume that we
      " are in a multiple var statement
      if (line =~ s:var_stmt)
        return lnum
      endif

      " other js keywords, not a var
      return 0
    endif

    let lnum = s:PrevNonBlankNonString(lnum - 1)
  endwhile

  " beginning of program, not a var
  return 0
endfunction

" Find line above with beginning of the var statement or returns 0 if it's not
" this statement
function s:GetVarIndent(lnum)
  let lvar = s:InMultiVarStatement(a:lnum)
  let prev_lnum = s:PrevNonBlankNonString(a:lnum - 1)

  if lvar
    let line = s:RemoveTrailingComments(getline(prev_lnum))

    " if the previous line doesn't end in a comma, return to regular indent
    if (line !~ s:comma_last)
      return indent(prev_lnum) - shiftwidth()
    else
      return indent(lvar) + shiftwidth()
    endif
  endif

  return -1
endfunction


" Check if line 'lnum' has more opening brackets than closing ones.
function s:LineHasOpeningBrackets(lnum)
  let open_0 = 0
  let open_2 = 0
  let open_4 = 0
  let line = getline(a:lnum)
  let pos = match(line, '[][(){}]', 0)
  while pos != -1
    if !s:IsInStringOrComment(a:lnum, pos + 1)
      let idx = stridx('(){}[]', line[pos])
      if idx % 2 == 0
        let open_{idx} = open_{idx} + 1
      else
        let open_{idx - 1} = open_{idx - 1} - 1
      endif
    endif
    let pos = match(line, '[][(){}]', pos + 1)
  endwhile
  return (open_0 > 0) . (open_2 > 0) . (open_4 > 0)
endfunction

function s:Match(lnum, regex)
  let col = match(getline(a:lnum), a:regex) + 1
  return col > 0 && !s:IsInStringOrComment(a:lnum, col) ? col : 0
endfunction

function s:IndentWithContinuation(lnum, ind, width)
  " Set up variables to use and search for MSL to the previous line.
  let p_lnum = a:lnum
  let lnum = s:GetMSL(a:lnum, 1)
  let line = getline(lnum)

  " If the previous line wasn't a MSL and is continuation return its indent.
  " TODO: the || s:IsInString() thing worries me a bit.
  if p_lnum != lnum
    if s:Match(p_lnum,s:continuation_regex)||s:IsInString(p_lnum,strlen(line))
      return a:ind
    endif
  endif

  " Set up more variables now that we know we aren't continuation bound.
  let msl_ind = indent(lnum)

  " If the previous line ended with [*+/.-=], start a continuation that
  " indents an extra level.
  if s:Match(lnum, s:continuation_regex)
    if lnum == p_lnum
      return msl_ind + a:width
    else
      return msl_ind
    endif
  endif

  return a:ind
endfunction

function s:InOneLineScope(lnum)
  let msl = s:GetMSL(a:lnum, 1)
  if msl > 0 && s:Match(msl, s:one_line_scope_regex)
    return msl
  endif
  return 0
endfunction

function s:ExitingOneLineScope(lnum)
  let msl = s:GetMSL(a:lnum, 1)
  if msl > 0
    " if the current line is in a one line scope ..
    if s:Match(msl, s:one_line_scope_regex)
      return 0
    else
      let prev_msl = s:GetMSL(msl - 1, 1)
      if s:Match(prev_msl, s:one_line_scope_regex)
        return prev_msl
      endif
    endif
  endif
  return 0
endfunction

" 3. GetTypescriptIndent Function {{{1
" =========================

function GetTypescriptIndent()
  " 3.1. Setup {{{2
  " ----------

  " Set up variables for restoring position in file.  Could use v:lnum here.
  let vcol = col('.')

  " 3.2. Work on the current line {{{2
  " -----------------------------

  let ind = -1
  " Get the current line.
  let line = getline(v:lnum)
  " previous nonblank line number
  let prevline = prevnonblank(v:lnum - 1)

  " If we got a closing bracket on an empty line, find its match and indent
  " according to it.  For parentheses we indent to its column - 1, for the
  " others we indent to the containing line's MSL's level.  Return -1 if fail.
  let col = matchend(line, '^\s*[],})]')
  if col > 0 && !s:IsInStringOrComment(v:lnum, col)
    call cursor(v:lnum, col)

    let lvar = s:InMultiVarStatement(v:lnum)
    if lvar
      let prevline_contents = s:RemoveTrailingComments(getline(prevline))

      " check for comma first
      if (line[col - 1] =~ ',')
        " if the previous line ends in comma or semicolon don't indent
        if (prevline_contents =~ '[;,]\s*$')
          return indent(s:GetMSL(line('.'), 0))
        " get previous line indent, if it's comma first return prevline indent
        elseif (prevline_contents =~ s:comma_first)
          return indent(prevline)
        " otherwise we indent 1 level
        else
          return indent(lvar) + shiftwidth()
        endif
      endif
    endif


    let bs = strpart('(){}[]', stridx(')}]', line[col - 1]) * 2, 2)
    if searchpair(escape(bs[0], '\['), '', bs[1], 'bW', s:skip_expr) > 0
      if line[col-1]==')' && col('.') != col('$') - 1
        let ind = virtcol('.')-1
      else
        let ind = indent(s:GetMSL(line('.'), 0))
      endif
    endif
    return ind
  endif

  " If the line is comma first, dedent 1 level
  if (getline(prevline) =~ s:comma_first)
    return indent(prevline) - shiftwidth()
  endif

  if (line =~ s:ternary)
    if (getline(prevline) =~ s:ternary_q)
      return indent(prevline)
    else
      return indent(prevline) + shiftwidth()
    endif
  endif

  " If we are in a multi-line comment, cindent does the right thing.
  if s:IsInMultilineComment(v:lnum, 1) && !s:IsLineComment(v:lnum, 1)
    return cindent(v:lnum)
  endif

  " Check for multiple var assignments
"  let var_indent = s:GetVarIndent(v:lnum)
"  if var_indent >= 0
"    return var_indent
"  endif

  " 3.3. Work on the previous line. {{{2
  " -------------------------------

  " If the line is empty and the previous nonblank line was a multi-line
  " comment, use that comment's indent. Deduct one char to account for the
  " space in ' */'.
  if line =~ '^\s*$' && s:IsInMultilineComment(prevline, 1)
    return indent(prevline) - 1
  endif

  " Find a non-blank, non-multi-line string line above the current line.
  let lnum = s:PrevNonBlankNonString(v:lnum - 1)

  " If the line is empty and inside a string, use the previous line.
  if line =~ '^\s*$' && lnum != prevline
    return indent(prevnonblank(v:lnum))
  endif

  " At the start of the file use zero indent.
  if lnum == 0
    return 0
  endif

  " Set up variables for current line.
  let line = getline(lnum)
  let ind = indent(lnum)

  " If the previous line ended with a block opening, add a level of indent.
  if s:Match(lnum, s:block_regex)
    return indent(s:GetMSL(lnum, 0)) + shiftwidth()
  endif

  " If the previous line contained an opening bracket, and we are still in it,
  " add indent depending on the bracket type.
  if line =~ '[[({]'
    let counts = s:LineHasOpeningBrackets(lnum)
    if counts[0] == '1' && searchpair('(', '', ')', 'bW', s:skip_expr) > 0
      if col('.') + 1 == col('$')
        return ind + shiftwidth()
      else
        return virtcol('.')
      endif
    elseif counts[1] == '1' || counts[2] == '1'
      return ind + shiftwidth()
    else
      call cursor(v:lnum, vcol)
    end
  endif

  " 3.4. Work on the MSL line. {{{2
  " --------------------------

  let ind_con = ind
  let ind = s:IndentWithContinuation(lnum, ind_con, shiftwidth())

  " }}}2
  "
  "
  let ols = s:InOneLineScope(lnum)
  if ols > 0
    let ind = ind + shiftwidth()
  else
    let ols = s:ExitingOneLineScope(lnum)
    while ols > 0 && ind > 0
      let ind = ind - shiftwidth()
      let ols = s:InOneLineScope(ols - 1)
    endwhile
  endif

  return ind
endfunction

" }}}1

let &cpo = s:cpo_save
unlet s:cpo_save

function! Fixedgq(lnum, count)
    let l:tw = &tw ? &tw : 80

    let l:count = a:count
    let l:first_char = indent(a:lnum) + 1

    if mode() == 'i' " gq was not pressed, but tw was set
        return 1
    endif

    " This gq is only meant to do code with strings, not comments
    if s:IsLineComment(a:lnum, l:first_char) || s:IsInMultilineComment(a:lnum, l:first_char)
        return 1
    endif

    if len(getline(a:lnum)) < l:tw && l:count == 1 " No need for gq
        return 1
    endif

    " Put all the lines on one line and do normal splitting after that
    if l:count > 1
        while l:count > 1
            let l:count -= 1
            normal J
        endwhile
    endif

    let l:winview = winsaveview()

    call cursor(a:lnum, l:tw + 1)
    let orig_breakpoint = searchpairpos(' ', '', '\.', 'bcW', '', a:lnum)
    call cursor(a:lnum, l:tw + 1)
    let breakpoint = searchpairpos(' ', '', '\.', 'bcW', s:skip_expr, a:lnum)

    " No need for special treatment, normal gq handles edgecases better
    if breakpoint[1] == orig_breakpoint[1]
        call winrestview(l:winview)
        return 1
    endif

    " Try breaking after string
    if breakpoint[1] <= indent(a:lnum)
        call cursor(a:lnum, l:tw + 1)
        let breakpoint = searchpairpos('\.', '', ' ', 'cW', s:skip_expr, a:lnum)
    endif


    if breakpoint[1] != 0
        call feedkeys("r\<CR>")
    else
        let l:count = l:count - 1
    endif

    " run gq on new lines
    if l:count == 1
        call feedkeys("gqq")
    endif

    return 0
endfunction
