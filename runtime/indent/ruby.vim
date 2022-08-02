" Vim indent file
" Language:		Ruby
" Maintainer:		Andrew Radev <andrey.radev@gmail.com>
" Previous Maintainer:	Nikolai Weibull <now at bitwi.se>
" URL:			https://github.com/vim-ruby/vim-ruby
" Release Coordinator:	Doug Kearns <dougkearns@gmail.com>
" Last Change:		2022 Mar 22

" 0. Initialization {{{1
" =================

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

if !exists('g:ruby_indent_access_modifier_style')
  " Possible values: "normal", "indent", "outdent"
  let g:ruby_indent_access_modifier_style = 'normal'
endif

if !exists('g:ruby_indent_assignment_style')
  " Possible values: "variable", "hanging"
  let g:ruby_indent_assignment_style = 'hanging'
endif

if !exists('g:ruby_indent_block_style')
  " Possible values: "expression", "do"
  let g:ruby_indent_block_style = 'do'
endif

if !exists('g:ruby_indent_hanging_elements')
  " Non-zero means hanging indents are enabled, zero means disabled
  let g:ruby_indent_hanging_elements = 1
endif

setlocal nosmartindent

" Now, set up our indentation expression and keys that trigger it.
setlocal indentexpr=GetRubyIndent(v:lnum)
setlocal indentkeys=0{,0},0),0],!^F,o,O,e,:,.
setlocal indentkeys+==end,=else,=elsif,=when,=in\ ,=ensure,=rescue,==begin,==end
setlocal indentkeys+==private,=protected,=public

let b:undo_indent = "setlocal indentexpr< indentkeys< smartindent<"

" Only define the function once.
if exists("*GetRubyIndent")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" 1. Variables {{{1
" ============

" Syntax group names that are strings.
let s:syng_string =
      \ ['String', 'Interpolation', 'InterpolationDelimiter', 'StringEscape']

" Syntax group names that are strings or documentation.
let s:syng_stringdoc = s:syng_string + ['Documentation']

" Syntax group names that are or delimit strings/symbols/regexes or are comments.
let s:syng_strcom = s:syng_stringdoc + [
      \ 'Character',
      \ 'Comment',
      \ 'HeredocDelimiter',
      \ 'PercentRegexpDelimiter',
      \ 'PercentStringDelimiter',
      \ 'PercentSymbolDelimiter',
      \ 'Regexp',
      \ 'RegexpCharClass',
      \ 'RegexpDelimiter',
      \ 'RegexpEscape',
      \ 'StringDelimiter',
      \ 'Symbol',
      \ 'SymbolDelimiter',
      \ ]

" Expression used to check whether we should skip a match with searchpair().
let s:skip_expr =
      \ 'index(map('.string(s:syng_strcom).',"hlID(''ruby''.v:val)"), synID(line("."),col("."),1)) >= 0'

" Regex used for words that, at the start of a line, add a level of indent.
let s:ruby_indent_keywords =
      \ '^\s*\zs\<\%(module\|class\|if\|for' .
      \   '\|while\|until\|else\|elsif\|case\|when\|in\|unless\|begin\|ensure\|rescue' .
      \   '\|\%(\K\k*[!?]\?\s\+\)\=def\):\@!\>' .
      \ '\|\%([=,*/%+-]\|<<\|>>\|:\s\)\s*\zs' .
      \    '\<\%(if\|for\|while\|until\|case\|unless\|begin\):\@!\>'

" Def without an end clause: def method_call(...) = <expression>
let s:ruby_endless_def = '\<def\s\+\k\+[!?]\=\%((.*)\|\s\)\s*='

" Regex used for words that, at the start of a line, remove a level of indent.
let s:ruby_deindent_keywords =
      \ '^\s*\zs\<\%(ensure\|else\|rescue\|elsif\|when\|in\|end\):\@!\>'

" Regex that defines the start-match for the 'end' keyword.
"let s:end_start_regex = '\%(^\|[^.]\)\<\%(module\|class\|def\|if\|for\|while\|until\|case\|unless\|begin\|do\)\>'
" TODO: the do here should be restricted somewhat (only at end of line)?
let s:end_start_regex =
      \ '\C\%(^\s*\|[=,*/%+\-|;{]\|<<\|>>\|:\s\)\s*\zs' .
      \ '\<\%(module\|class\|if\|for\|while\|until\|case\|unless\|begin' .
      \   '\|\%(\K\k*[!?]\?\s\+\)\=def\):\@!\>' .
      \ '\|\%(^\|[^.:@$]\)\@<=\<do:\@!\>'

" Regex that defines the middle-match for the 'end' keyword.
let s:end_middle_regex = '\<\%(ensure\|else\|\%(\%(^\|;\)\s*\)\@<=\<rescue:\@!\>\|when\|\%(\%(^\|;\)\s*\)\@<=\<in\|elsif\):\@!\>'

" Regex that defines the end-match for the 'end' keyword.
let s:end_end_regex = '\%(^\|[^.:@$]\)\@<=\<end:\@!\>'

" Expression used for searchpair() call for finding a match for an 'end' keyword.
function! s:EndSkipExpr()
  if eval(s:skip_expr)
    return 1
  elseif expand('<cword>') == 'do'
        \ && getline(".") =~ '^\s*\<\(while\|until\|for\):\@!\>'
    return 1
  elseif getline('.') =~ s:ruby_endless_def
    return 1
  elseif getline('.') =~ '\<def\s\+\k\+[!?]\=([^)]*$'
    " Then it's a `def method(` with a possible `) =` later
    call search('\<def\s\+\k\+\zs(', 'W', line('.'))
    normal! %
    return getline('.') =~ ')\s*='
  else
    return 0
  endif
endfunction

let s:end_skip_expr = function('s:EndSkipExpr')

" Regex that defines continuation lines, not including (, {, or [.
let s:non_bracket_continuation_regex =
      \ '\%([\\.,:*/%+]\|\<and\|\<or\|\%(<%\)\@<![=-]\|:\@<![^[:alnum:]:][|&?]\|||\|&&\)\s*\%(#.*\)\=$'

" Regex that defines continuation lines.
let s:continuation_regex =
      \ '\%(%\@<![({[\\.,:*/%+]\|\<and\|\<or\|\%(<%\)\@<![=-]\|:\@<![^[:alnum:]:][|&?]\|||\|&&\)\s*\%(#.*\)\=$'

" Regex that defines continuable keywords
let s:continuable_regex =
      \ '\C\%(^\s*\|[=,*/%+\-|;{]\|<<\|>>\|:\s\)\s*\zs' .
      \ '\<\%(if\|for\|while\|until\|unless\):\@!\>'

" Regex that defines bracket continuations
let s:bracket_continuation_regex = '%\@<!\%([({[]\)\s*\%(#.*\)\=$'

" Regex that defines dot continuations
let s:dot_continuation_regex = '%\@<!\.\s*\%(#.*\)\=$'

" Regex that defines backslash continuations
let s:backslash_continuation_regex = '%\@<!\\\s*$'

" Regex that defines end of bracket continuation followed by another continuation
let s:bracket_switch_continuation_regex = '^\([^(]\+\zs).\+\)\+'.s:continuation_regex

" Regex that defines the first part of a splat pattern
let s:splat_regex = '[[,(]\s*\*\s*\%(#.*\)\=$'

" Regex that describes all indent access modifiers
let s:access_modifier_regex = '\C^\s*\%(public\|protected\|private\)\s*\%(#.*\)\=$'

" Regex that describes the indent access modifiers (excludes public)
let s:indent_access_modifier_regex = '\C^\s*\%(protected\|private\)\s*\%(#.*\)\=$'

" Regex that defines blocks.
"
" Note that there's a slight problem with this regex and s:continuation_regex.
" Code like this will be matched by both:
"
"   method_call do |(a, b)|
"
" The reason is that the pipe matches a hanging "|" operator.
"
let s:block_regex =
      \ '\%(\<do:\@!\>\|%\@<!{\)\s*\%(|[^|]*|\)\=\s*\%(#.*\)\=$'

let s:block_continuation_regex = '^\s*[^])}\t ].*'.s:block_regex

" Regex that describes a leading operator (only a method call's dot for now)
let s:leading_operator_regex = '^\s*\%(&\=\.\)'

" 2. GetRubyIndent Function {{{1
" =========================

function! GetRubyIndent(...) abort
  " 2.1. Setup {{{2
  " ----------

  let indent_info = {}

  " The value of a single shift-width
  if exists('*shiftwidth')
    let indent_info.sw = shiftwidth()
  else
    let indent_info.sw = &sw
  endif

  " For the current line, use the first argument if given, else v:lnum
  let indent_info.clnum = a:0 ? a:1 : v:lnum
  let indent_info.cline = getline(indent_info.clnum)

  " Set up variables for restoring position in file.  Could use clnum here.
  let indent_info.col = col('.')

  " 2.2. Work on the current line {{{2
  " -----------------------------
  let indent_callback_names = [
        \ 's:AccessModifier',
        \ 's:ClosingBracketOnEmptyLine',
        \ 's:BlockComment',
        \ 's:DeindentingKeyword',
        \ 's:MultilineStringOrLineComment',
        \ 's:ClosingHeredocDelimiter',
        \ 's:LeadingOperator',
        \ ]

  for callback_name in indent_callback_names
"    Decho "Running: ".callback_name
    let indent = call(function(callback_name), [indent_info])

    if indent >= 0
"      Decho "Match: ".callback_name." indent=".indent." info=".string(indent_info)
      return indent
    endif
  endfor

  " 2.3. Work on the previous line. {{{2
  " -------------------------------

  " Special case: we don't need the real s:PrevNonBlankNonString for an empty
  " line inside a string. And that call can be quite expensive in that
  " particular situation.
  let indent_callback_names = [
        \ 's:EmptyInsideString',
        \ ]

  for callback_name in indent_callback_names
"    Decho "Running: ".callback_name
    let indent = call(function(callback_name), [indent_info])

    if indent >= 0
"      Decho "Match: ".callback_name." indent=".indent." info=".string(indent_info)
      return indent
    endif
  endfor

  " Previous line number
  let indent_info.plnum = s:PrevNonBlankNonString(indent_info.clnum - 1)
  let indent_info.pline = getline(indent_info.plnum)

  let indent_callback_names = [
        \ 's:StartOfFile',
        \ 's:AfterAccessModifier',
        \ 's:ContinuedLine',
        \ 's:AfterBlockOpening',
        \ 's:AfterHangingSplat',
        \ 's:AfterUnbalancedBracket',
        \ 's:AfterLeadingOperator',
        \ 's:AfterEndKeyword',
        \ 's:AfterIndentKeyword',
        \ ]

  for callback_name in indent_callback_names
"    Decho "Running: ".callback_name
    let indent = call(function(callback_name), [indent_info])

    if indent >= 0
"      Decho "Match: ".callback_name." indent=".indent." info=".string(indent_info)
      return indent
    endif
  endfor

  " 2.4. Work on the MSL line. {{{2
  " --------------------------
  let indent_callback_names = [
        \ 's:PreviousNotMSL',
        \ 's:IndentingKeywordInMSL',
        \ 's:ContinuedHangingOperator',
        \ ]

  " Most Significant line based on the previous one -- in case it's a
  " continuation of something above
  let indent_info.plnum_msl = s:GetMSL(indent_info.plnum)

  for callback_name in indent_callback_names
"    Decho "Running: ".callback_name
    let indent = call(function(callback_name), [indent_info])

    if indent >= 0
"      Decho "Match: ".callback_name." indent=".indent." info=".string(indent_info)
      return indent
    endif
  endfor

  " }}}2

  " By default, just return the previous line's indent
"  Decho "Default case matched"
  return indent(indent_info.plnum)
endfunction

" 3. Indenting Logic Callbacks {{{1
" ============================

function! s:AccessModifier(cline_info) abort
  let info = a:cline_info

  " If this line is an access modifier keyword, align according to the closest
  " class declaration.
  if g:ruby_indent_access_modifier_style == 'indent'
    if s:Match(info.clnum, s:access_modifier_regex)
      let class_lnum = s:FindContainingClass()
      if class_lnum > 0
        return indent(class_lnum) + info.sw
      endif
    endif
  elseif g:ruby_indent_access_modifier_style == 'outdent'
    if s:Match(info.clnum, s:access_modifier_regex)
      let class_lnum = s:FindContainingClass()
      if class_lnum > 0
        return indent(class_lnum)
      endif
    endif
  endif

  return -1
endfunction

function! s:ClosingBracketOnEmptyLine(cline_info) abort
  let info = a:cline_info

  " If we got a closing bracket on an empty line, find its match and indent
  " according to it.  For parentheses we indent to its column - 1, for the
  " others we indent to the containing line's MSL's level.  Return -1 if fail.
  let col = matchend(info.cline, '^\s*[]})]')

  if col > 0 && !s:IsInStringOrComment(info.clnum, col)
    call cursor(info.clnum, col)
    let closing_bracket = info.cline[col - 1]
    let bracket_pair = strpart('(){}[]', stridx(')}]', closing_bracket) * 2, 2)

    if searchpair(escape(bracket_pair[0], '\['), '', bracket_pair[1], 'bW', s:skip_expr) > 0
      if closing_bracket == ')' && col('.') != col('$') - 1
        if g:ruby_indent_hanging_elements
          let ind = virtcol('.') - 1
        else
          let ind = indent(line('.'))
        end
      elseif g:ruby_indent_block_style == 'do'
        let ind = indent(line('.'))
      else " g:ruby_indent_block_style == 'expression'
        let ind = indent(s:GetMSL(line('.')))
      endif
    endif

    return ind
  endif

  return -1
endfunction

function! s:BlockComment(cline_info) abort
  " If we have a =begin or =end set indent to first column.
  if match(a:cline_info.cline, '^\s*\%(=begin\|=end\)$') != -1
    return 0
  endif
  return -1
endfunction

function! s:DeindentingKeyword(cline_info) abort
  let info = a:cline_info

  " If we have a deindenting keyword, find its match and indent to its level.
  " TODO: this is messy
  if s:Match(info.clnum, s:ruby_deindent_keywords)
    call cursor(info.clnum, 1)

    if searchpair(s:end_start_regex, s:end_middle_regex, s:end_end_regex, 'bW',
          \ s:end_skip_expr) > 0
      let msl  = s:GetMSL(line('.'))
      let line = getline(line('.'))

      if s:IsAssignment(line, col('.')) &&
            \ strpart(line, col('.') - 1, 2) !~ 'do'
        " assignment to case/begin/etc, on the same line
        if g:ruby_indent_assignment_style == 'hanging'
          " hanging indent
          let ind = virtcol('.') - 1
        else
          " align with variable
          let ind = indent(line('.'))
        endif
      elseif g:ruby_indent_block_style == 'do'
        " align to line of the "do", not to the MSL
        let ind = indent(line('.'))
      elseif getline(msl) =~ '=\s*\(#.*\)\=$'
        " in the case of assignment to the MSL, align to the starting line,
        " not to the MSL
        let ind = indent(line('.'))
      else
        " align to the MSL
        let ind = indent(msl)
      endif
    endif
    return ind
  endif

  return -1
endfunction

function! s:MultilineStringOrLineComment(cline_info) abort
  let info = a:cline_info

  " If we are in a multi-line string or line-comment, don't do anything to it.
  if s:IsInStringOrDocumentation(info.clnum, matchend(info.cline, '^\s*') + 1)
    return indent(info.clnum)
  endif
  return -1
endfunction

function! s:ClosingHeredocDelimiter(cline_info) abort
  let info = a:cline_info

  " If we are at the closing delimiter of a "<<" heredoc-style string, set the
  " indent to 0.
  if info.cline =~ '^\k\+\s*$'
        \ && s:IsInStringDelimiter(info.clnum, 1)
        \ && search('\V<<'.info.cline, 'nbW') > 0
    return 0
  endif

  return -1
endfunction

function! s:LeadingOperator(cline_info) abort
  " If the current line starts with a leading operator, add a level of indent.
  if s:Match(a:cline_info.clnum, s:leading_operator_regex)
    return indent(s:GetMSL(a:cline_info.clnum)) + a:cline_info.sw
  endif
  return -1
endfunction

function! s:EmptyInsideString(pline_info) abort
  " If the line is empty and inside a string (the previous line is a string,
  " too), use the previous line's indent
  let info = a:pline_info

  let plnum = prevnonblank(info.clnum - 1)
  let pline = getline(plnum)

  if info.cline =~ '^\s*$'
        \ && s:IsInStringOrComment(plnum, 1)
        \ && s:IsInStringOrComment(plnum, strlen(pline))
    return indent(plnum)
  endif
  return -1
endfunction

function! s:StartOfFile(pline_info) abort
  " At the start of the file use zero indent.
  if a:pline_info.plnum == 0
    return 0
  endif
  return -1
endfunction

function! s:AfterAccessModifier(pline_info) abort
  let info = a:pline_info

  if g:ruby_indent_access_modifier_style == 'indent'
    " If the previous line was a private/protected keyword, add a
    " level of indent.
    if s:Match(info.plnum, s:indent_access_modifier_regex)
      return indent(info.plnum) + info.sw
    endif
  elseif g:ruby_indent_access_modifier_style == 'outdent'
    " If the previous line was a private/protected/public keyword, add
    " a level of indent, since the keyword has been out-dented.
    if s:Match(info.plnum, s:access_modifier_regex)
      return indent(info.plnum) + info.sw
    endif
  endif
  return -1
endfunction

" Example:
"
"   if foo || bar ||
"       baz || bing
"     puts "foo"
"   end
"
function! s:ContinuedLine(pline_info) abort
  let info = a:pline_info

  let col = s:Match(info.plnum, s:ruby_indent_keywords)
  if s:Match(info.plnum, s:continuable_regex) &&
        \ s:Match(info.plnum, s:continuation_regex)
    if col > 0 && s:IsAssignment(info.pline, col)
      if g:ruby_indent_assignment_style == 'hanging'
        " hanging indent
        let ind = col - 1
      else
        " align with variable
        let ind = indent(info.plnum)
      endif
    else
      let ind = indent(s:GetMSL(info.plnum))
    endif
    return ind + info.sw + info.sw
  endif
  return -1
endfunction

function! s:AfterBlockOpening(pline_info) abort
  let info = a:pline_info

  " If the previous line ended with a block opening, add a level of indent.
  if s:Match(info.plnum, s:block_regex)
    if g:ruby_indent_block_style == 'do'
      " don't align to the msl, align to the "do"
      let ind = indent(info.plnum) + info.sw
    else
      let plnum_msl = s:GetMSL(info.plnum)

      if getline(plnum_msl) =~ '=\s*\(#.*\)\=$'
        " in the case of assignment to the msl, align to the starting line,
        " not to the msl
        let ind = indent(info.plnum) + info.sw
      else
        let ind = indent(plnum_msl) + info.sw
      endif
    endif

    return ind
  endif

  return -1
endfunction

function! s:AfterLeadingOperator(pline_info) abort
  " If the previous line started with a leading operator, use its MSL's level
  " of indent
  if s:Match(a:pline_info.plnum, s:leading_operator_regex)
    return indent(s:GetMSL(a:pline_info.plnum))
  endif
  return -1
endfunction

function! s:AfterHangingSplat(pline_info) abort
  let info = a:pline_info

  " If the previous line ended with the "*" of a splat, add a level of indent
  if info.pline =~ s:splat_regex
    return indent(info.plnum) + info.sw
  endif
  return -1
endfunction

function! s:AfterUnbalancedBracket(pline_info) abort
  let info = a:pline_info

  " If the previous line contained unclosed opening brackets and we are still
  " in them, find the rightmost one and add indent depending on the bracket
  " type.
  "
  " If it contained hanging closing brackets, find the rightmost one, find its
  " match and indent according to that.
  if info.pline =~ '[[({]' || info.pline =~ '[])}]\s*\%(#.*\)\=$'
    let [opening, closing] = s:ExtraBrackets(info.plnum)

    if opening.pos != -1
      if !g:ruby_indent_hanging_elements
        return indent(info.plnum) + info.sw
      elseif opening.type == '(' && searchpair('(', '', ')', 'bW', s:skip_expr) > 0
        if col('.') + 1 == col('$')
          return indent(info.plnum) + info.sw
        else
          return virtcol('.')
        endif
      else
        let nonspace = matchend(info.pline, '\S', opening.pos + 1) - 1
        return nonspace > 0 ? nonspace : indent(info.plnum) + info.sw
      endif
    elseif closing.pos != -1
      call cursor(info.plnum, closing.pos + 1)
      normal! %

      if strpart(info.pline, closing.pos) =~ '^)\s*='
        " special case: the closing `) =` of an endless def
        return indent(s:GetMSL(line('.')))
      endif

      if s:Match(line('.'), s:ruby_indent_keywords)
        return indent('.') + info.sw
      else
        return indent(s:GetMSL(line('.')))
      endif
    else
      call cursor(info.clnum, info.col)
    end
  endif

  return -1
endfunction

function! s:AfterEndKeyword(pline_info) abort
  let info = a:pline_info
  " If the previous line ended with an "end", match that "end"s beginning's
  " indent.
  let col = s:Match(info.plnum, '\%(^\|[^.:@$]\)\<end\>\s*\%(#.*\)\=$')
  if col > 0
    call cursor(info.plnum, col)
    if searchpair(s:end_start_regex, '', s:end_end_regex, 'bW',
          \ s:end_skip_expr) > 0
      let n = line('.')
      let ind = indent('.')
      let msl = s:GetMSL(n)
      if msl != n
        let ind = indent(msl)
      end
      return ind
    endif
  end
  return -1
endfunction

function! s:AfterIndentKeyword(pline_info) abort
  let info = a:pline_info
  let col = s:Match(info.plnum, s:ruby_indent_keywords)

  if col > 0 && s:Match(info.plnum, s:ruby_endless_def) <= 0
    call cursor(info.plnum, col)
    let ind = virtcol('.') - 1 + info.sw
    " TODO: make this better (we need to count them) (or, if a searchpair
    " fails, we know that something is lacking an end and thus we indent a
    " level
    if s:Match(info.plnum, s:end_end_regex)
      let ind = indent('.')
    elseif s:IsAssignment(info.pline, col)
      if g:ruby_indent_assignment_style == 'hanging'
        " hanging indent
        let ind = col + info.sw - 1
      else
        " align with variable
        let ind = indent(info.plnum) + info.sw
      endif
    endif
    return ind
  endif

  return -1
endfunction

function! s:PreviousNotMSL(msl_info) abort
  let info = a:msl_info

  " If the previous line wasn't a MSL
  if info.plnum != info.plnum_msl
    " If previous line ends bracket and begins non-bracket continuation decrease indent by 1.
    if s:Match(info.plnum, s:bracket_switch_continuation_regex)
      " TODO (2016-10-07) Wrong/unused? How could it be "1"?
      return indent(info.plnum) - 1
      " If previous line is a continuation return its indent.
    elseif s:Match(info.plnum, s:non_bracket_continuation_regex)
      return indent(info.plnum)
    endif
  endif

  return -1
endfunction

function! s:IndentingKeywordInMSL(msl_info) abort
  let info = a:msl_info
  " If the MSL line had an indenting keyword in it, add a level of indent.
  " TODO: this does not take into account contrived things such as
  " module Foo; class Bar; end
  let col = s:Match(info.plnum_msl, s:ruby_indent_keywords)
  if col > 0 && s:Match(info.plnum_msl, s:ruby_endless_def) <= 0
    let ind = indent(info.plnum_msl) + info.sw
    if s:Match(info.plnum_msl, s:end_end_regex)
      let ind = ind - info.sw
    elseif s:IsAssignment(getline(info.plnum_msl), col)
      if g:ruby_indent_assignment_style == 'hanging'
        " hanging indent
        let ind = col + info.sw - 1
      else
        " align with variable
        let ind = indent(info.plnum_msl) + info.sw
      endif
    endif
    return ind
  endif
  return -1
endfunction

function! s:ContinuedHangingOperator(msl_info) abort
  let info = a:msl_info

  " If the previous line ended with [*+/.,-=], but wasn't a block ending or a
  " closing bracket, indent one extra level.
  if s:Match(info.plnum_msl, s:non_bracket_continuation_regex) && !s:Match(info.plnum_msl, '^\s*\([\])}]\|end\)')
    if info.plnum_msl == info.plnum
      let ind = indent(info.plnum_msl) + info.sw
    else
      let ind = indent(info.plnum_msl)
    endif
    return ind
  endif

  return -1
endfunction

" 4. Auxiliary Functions {{{1
" ======================

function! s:IsInRubyGroup(groups, lnum, col) abort
  let ids = map(copy(a:groups), 'hlID("ruby".v:val)')
  return index(ids, synID(a:lnum, a:col, 1)) >= 0
endfunction

" Check if the character at lnum:col is inside a string, comment, or is ascii.
function! s:IsInStringOrComment(lnum, col) abort
  return s:IsInRubyGroup(s:syng_strcom, a:lnum, a:col)
endfunction

" Check if the character at lnum:col is inside a string.
function! s:IsInString(lnum, col) abort
  return s:IsInRubyGroup(s:syng_string, a:lnum, a:col)
endfunction

" Check if the character at lnum:col is inside a string or documentation.
function! s:IsInStringOrDocumentation(lnum, col) abort
  return s:IsInRubyGroup(s:syng_stringdoc, a:lnum, a:col)
endfunction

" Check if the character at lnum:col is inside a string delimiter
function! s:IsInStringDelimiter(lnum, col) abort
  return s:IsInRubyGroup(
        \ ['HeredocDelimiter', 'PercentStringDelimiter', 'StringDelimiter'],
        \ a:lnum, a:col
        \ )
endfunction

function! s:IsAssignment(str, pos) abort
  return strpart(a:str, 0, a:pos - 1) =~ '=\s*$'
endfunction

" Find line above 'lnum' that isn't empty, in a comment, or in a string.
function! s:PrevNonBlankNonString(lnum) abort
  let in_block = 0
  let lnum = prevnonblank(a:lnum)
  while lnum > 0
    " Go in and out of blocks comments as necessary.
    " If the line isn't empty (with opt. comment) or in a string, end search.
    let line = getline(lnum)
    if line =~ '^=begin'
      if in_block
        let in_block = 0
      else
        break
      endif
    elseif !in_block && line =~ '^=end'
      let in_block = 1
    elseif !in_block && line !~ '^\s*#.*$' && !(s:IsInStringOrComment(lnum, 1)
          \ && s:IsInStringOrComment(lnum, strlen(line)))
      break
    endif
    let lnum = prevnonblank(lnum - 1)
  endwhile
  return lnum
endfunction

" Find line above 'lnum' that started the continuation 'lnum' may be part of.
function! s:GetMSL(lnum) abort
  " Start on the line we're at and use its indent.
  let msl = a:lnum
  let lnum = s:PrevNonBlankNonString(a:lnum - 1)
  while lnum > 0
    " If we have a continuation line, or we're in a string, use line as MSL.
    " Otherwise, terminate search as we have found our MSL already.
    let line = getline(lnum)

    if !s:Match(msl, s:backslash_continuation_regex) &&
          \ s:Match(lnum, s:backslash_continuation_regex)
      " If the current line doesn't end in a backslash, but the previous one
      " does, look for that line's msl
      "
      " Example:
      "   foo = "bar" \
      "     "baz"
      "
      let msl = lnum
    elseif s:Match(msl, s:leading_operator_regex)
      " If the current line starts with a leading operator, keep its indent
      " and keep looking for an MSL.
      let msl = lnum
    elseif s:Match(lnum, s:splat_regex)
      " If the above line looks like the "*" of a splat, use the current one's
      " indentation.
      "
      " Example:
      "   Hash[*
      "     method_call do
      "       something
      "
      return msl
    elseif s:Match(lnum, s:non_bracket_continuation_regex) &&
          \ s:Match(msl, s:non_bracket_continuation_regex)
      " If the current line is a non-bracket continuation and so is the
      " previous one, keep its indent and continue looking for an MSL.
      "
      " Example:
      "   method_call one,
      "     two,
      "     three
      "
      let msl = lnum
    elseif s:Match(lnum, s:dot_continuation_regex) &&
          \ (s:Match(msl, s:bracket_continuation_regex) || s:Match(msl, s:block_continuation_regex))
      " If the current line is a bracket continuation or a block-starter, but
      " the previous is a dot, keep going to see if the previous line is the
      " start of another continuation.
      "
      " Example:
      "   parent.
      "     method_call {
      "     three
      "
      let msl = lnum
    elseif s:Match(lnum, s:non_bracket_continuation_regex) &&
          \ (s:Match(msl, s:bracket_continuation_regex) || s:Match(msl, s:block_continuation_regex))
      " If the current line is a bracket continuation or a block-starter, but
      " the previous is a non-bracket one, respect the previous' indentation,
      " and stop here.
      "
      " Example:
      "   method_call one,
      "     two {
      "     three
      "
      return lnum
    elseif s:Match(lnum, s:bracket_continuation_regex) &&
          \ (s:Match(msl, s:bracket_continuation_regex) || s:Match(msl, s:block_continuation_regex))
      " If both lines are bracket continuations (the current may also be a
      " block-starter), use the current one's and stop here
      "
      " Example:
      "   method_call(
      "     other_method_call(
      "       foo
      return msl
    elseif s:Match(lnum, s:block_regex) &&
          \ !s:Match(msl, s:continuation_regex) &&
          \ !s:Match(msl, s:block_continuation_regex)
      " If the previous line is a block-starter and the current one is
      " mostly ordinary, use the current one as the MSL.
      "
      " Example:
      "   method_call do
      "     something
      "     something_else
      return msl
    else
      let col = match(line, s:continuation_regex) + 1
      if (col > 0 && !s:IsInStringOrComment(lnum, col))
            \ || s:IsInString(lnum, strlen(line))
        let msl = lnum
      else
        break
      endif
    endif

    let lnum = s:PrevNonBlankNonString(lnum - 1)
  endwhile
  return msl
endfunction

" Check if line 'lnum' has more opening brackets than closing ones.
function! s:ExtraBrackets(lnum) abort
  let opening = {'parentheses': [], 'braces': [], 'brackets': []}
  let closing = {'parentheses': [], 'braces': [], 'brackets': []}

  let line = getline(a:lnum)
  let pos  = match(line, '[][(){}]', 0)

  " Save any encountered opening brackets, and remove them once a matching
  " closing one has been found. If a closing bracket shows up that doesn't
  " close anything, save it for later.
  while pos != -1
    if !s:IsInStringOrComment(a:lnum, pos + 1)
      if line[pos] == '('
        call add(opening.parentheses, {'type': '(', 'pos': pos})
      elseif line[pos] == ')'
        if empty(opening.parentheses)
          call add(closing.parentheses, {'type': ')', 'pos': pos})
        else
          let opening.parentheses = opening.parentheses[0:-2]
        endif
      elseif line[pos] == '{'
        call add(opening.braces, {'type': '{', 'pos': pos})
      elseif line[pos] == '}'
        if empty(opening.braces)
          call add(closing.braces, {'type': '}', 'pos': pos})
        else
          let opening.braces = opening.braces[0:-2]
        endif
      elseif line[pos] == '['
        call add(opening.brackets, {'type': '[', 'pos': pos})
      elseif line[pos] == ']'
        if empty(opening.brackets)
          call add(closing.brackets, {'type': ']', 'pos': pos})
        else
          let opening.brackets = opening.brackets[0:-2]
        endif
      endif
    endif

    let pos = match(line, '[][(){}]', pos + 1)
  endwhile

  " Find the rightmost brackets, since they're the ones that are important in
  " both opening and closing cases
  let rightmost_opening = {'type': '(', 'pos': -1}
  let rightmost_closing = {'type': ')', 'pos': -1}

  for opening in opening.parentheses + opening.braces + opening.brackets
    if opening.pos > rightmost_opening.pos
      let rightmost_opening = opening
    endif
  endfor

  for closing in closing.parentheses + closing.braces + closing.brackets
    if closing.pos > rightmost_closing.pos
      let rightmost_closing = closing
    endif
  endfor

  return [rightmost_opening, rightmost_closing]
endfunction

function! s:Match(lnum, regex) abort
  let line   = getline(a:lnum)
  let offset = match(line, '\C'.a:regex)
  let col    = offset + 1

  while offset > -1 && s:IsInStringOrComment(a:lnum, col)
    let offset = match(line, '\C'.a:regex, offset + 1)
    let col = offset + 1
  endwhile

  if offset > -1
    return col
  else
    return 0
  endif
endfunction

" Locates the containing class/module's definition line, ignoring nested classes
" along the way.
"
function! s:FindContainingClass() abort
  let saved_position = getpos('.')

  while searchpair(s:end_start_regex, s:end_middle_regex, s:end_end_regex, 'bW',
        \ s:end_skip_expr) > 0
    if expand('<cword>') =~# '\<class\|module\>'
      let found_lnum = line('.')
      call setpos('.', saved_position)
      return found_lnum
    endif
  endwhile

  call setpos('.', saved_position)
  return 0
endfunction

" }}}1

let &cpo = s:cpo_save
unlet s:cpo_save

" vim:set sw=2 sts=2 ts=8 et:
