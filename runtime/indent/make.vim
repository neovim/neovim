" Vim indent file
" Language:		Makefile
" Maintainer:		Doug Kearns <dougkearns@gmail.com>
" Previous Maintainer:	Nikolai Weibull <now@bitwi.se>
" Last Change:		2022 Apr 06

if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal indentexpr=GetMakeIndent()
setlocal indentkeys=!^F,o,O,<:>,=else,=endif
setlocal nosmartindent

let b:undo_indent = "setl inde< indk< si<"

if exists("*GetMakeIndent")
  finish
endif

let s:comment_rx = '^\s*#'
let s:rule_rx = '^[^ \t#:][^#:]*:\{1,2}\%([^=:]\|$\)'
let s:continued_rule_rx = '^[^#:]*:\{1,2}\%([^=:]\|$\)'
let s:continuation_rx = '\\$'
let s:assignment_rx = '^\s*\h\w*\s*[+:?]\==\s*\zs.*\\$'
let s:folded_assignment_rx = '^\s*\h\w*\s*[+:?]\=='
" TODO: This needs to be a lot more restrictive in what it matches.
let s:just_inserted_rule_rx = '^\s*[^#:]\+:\{1,2}$'
let s:conditional_directive_rx = '^ *\%(ifn\=\%(eq\|def\)\|else\)\>'
let s:end_conditional_directive_rx = '^\s*\%(else\|endif\)\>'

function s:remove_continuation(line)
  return substitute(a:line, s:continuation_rx, "", "")
endfunction

function GetMakeIndent()
  " TODO: Should this perhaps be v:lnum -1?
"  let prev_lnum = prevnonblank(v:lnum - 1)
  let prev_lnum = v:lnum - 1
  if prev_lnum == 0
    return 0
  endif
  let prev_line = getline(prev_lnum)

  let prev_prev_lnum = prev_lnum - 1
  let prev_prev_line = prev_prev_lnum != 0 ? getline(prev_prev_lnum) : ""

  " TODO: Deal with comments.  In comments, continuations aren't interesting.
  if prev_line =~ s:continuation_rx
    if prev_prev_line =~ s:continuation_rx
      return indent(prev_lnum)
    elseif prev_line =~ s:rule_rx
      return shiftwidth()
    elseif prev_line =~ s:assignment_rx
      call cursor(prev_lnum, 1)
      if search(s:assignment_rx, 'W') != 0
        return virtcol('.') - 1
      else
        " TODO: ?
        return shiftwidth()
      endif
    else
      " TODO: OK, this might be a continued shell command, so perhaps indent
      " properly here?  Leave this out for now, but in the next release this
      " should be using indent/sh.vim somehow.
      "if prev_line =~ '^\t' " s:rule_command_rx
      "  if prev_line =~ '^\s\+[@-]\%(if\)\>'
      "    return indent(prev_lnum) + 2
      "  endif
      "endif
      return indent(prev_lnum) + shiftwidth()
    endif
  elseif prev_prev_line =~ s:continuation_rx
    let folded_line = s:remove_continuation(prev_prev_line) . ' ' . s:remove_continuation(prev_line)
    let lnum = prev_prev_lnum - 1
    let line = getline(lnum)
    while line =~ s:continuation_rx
      let folded_line = s:remove_continuation(line) . ' ' . folded_line
      let lnum -= 1
      let line = getline(lnum)
    endwhile
    let folded_lnum = lnum + 1
    if folded_line =~ s:rule_rx
      if getline(v:lnum) =~ s:rule_rx
        return 0
      else
        return &ts
      endif
    else
"    elseif folded_line =~ s:folded_assignment_rx
      if getline(v:lnum) =~ s:rule_rx
        return 0
      else
        return indent(folded_lnum)
      endif
"    else
"      " TODO: ?
"      return indent(prev_lnum)
    endif
  elseif prev_line =~ s:rule_rx
    if getline(v:lnum) =~ s:rule_rx
      return 0
    else
      return &ts
    endif
  elseif prev_line =~ s:conditional_directive_rx
    return shiftwidth()
  else
    let line = getline(v:lnum)
    if line =~ s:just_inserted_rule_rx
      return 0
    elseif line =~ s:end_conditional_directive_rx
      return v:lnum - 1 == 0 ? 0 : indent(v:lnum - 1) - shiftwidth()
    else
      return v:lnum - 1 == 0 ? 0 : indent(v:lnum - 1)
    endif
  endif
endfunction
