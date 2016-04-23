" Vim indent file
" Language:            Shell Script
" Maintainer:          Christian Brabandt <cb@256bit.org>
" Previous Maintainer: Peter Aronoff <telemachus@arpinum.org>
" Original Author:     Nikolai Weibull <now@bitwi.se>
" Latest Revision:     2015-07-28
" License:             Vim (see :h license)
" Repository:          https://github.com/chrisbra/vim-sh-indent

if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal indentexpr=GetShIndent()
setlocal indentkeys+=0=then,0=do,0=else,0=elif,0=fi,0=esac,0=done,0=end,),0=;;,0=;&
setlocal indentkeys+=0=fin,0=fil,0=fip,0=fir,0=fix
setlocal indentkeys-=:,0#
setlocal nosmartindent

if exists("*GetShIndent")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

function s:buffer_shiftwidth()
  return &shiftwidth
endfunction

let s:sh_indent_defaults = {
      \ 'default': function('s:buffer_shiftwidth'),
      \ 'continuation-line': function('s:buffer_shiftwidth'),
      \ 'case-labels': function('s:buffer_shiftwidth'),
      \ 'case-statements': function('s:buffer_shiftwidth'),
      \ 'case-breaks': 0 }

function! s:indent_value(option)
  let Value = exists('b:sh_indent_options')
            \ && has_key(b:sh_indent_options, a:option) ?
            \ b:sh_indent_options[a:option] :
            \ s:sh_indent_defaults[a:option]
  if type(Value) == type(function('type'))
    return Value()
  endif
  return Value
endfunction

function! GetShIndent()
  let lnum = prevnonblank(v:lnum - 1)
  if lnum == 0
    return 0
  endif

  let pnum = prevnonblank(lnum - 1)

  let ind = indent(lnum)
  let line = getline(lnum)
  if line =~ '^\s*\%(if\|then\|do\|else\|elif\|case\|while\|until\|for\|select\|foreach\)\>'
    if line !~ '\<\%(fi\|esac\|done\|end\)\>\s*\%(#.*\)\=$'
      let ind += s:indent_value('default')
    endif
  elseif s:is_case_label(line, pnum)
    if !s:is_case_ended(line)
      let ind += s:indent_value('case-statements')
    endif
  elseif line =~ '^\s*\<\k\+\>\s*()\s*{' || line =~ '^\s*{'
    if line !~ '}\s*\%(#.*\)\=$'
      let ind += s:indent_value('default')
    endif
  elseif s:is_continuation_line(line)
    if pnum == 0 || !s:is_continuation_line(getline(pnum))
      let ind += s:indent_value('continuation-line')
    endif
  elseif pnum != 0 && s:is_continuation_line(getline(pnum))
    let ind = indent(s:find_continued_lnum(pnum))
  endif

  let pine = line
  let line = getline(v:lnum)
  if line =~ '^\s*\%(then\|do\|else\|elif\|fi\|done\|end\)\>' || line =~ '^\s*}'
    let ind -= s:indent_value('default')
  elseif line =~ '^\s*esac\>' && s:is_case_empty(getline(v:lnum - 1))
    let ind -= s:indent_value('default')
  elseif line =~ '^\s*esac\>'
    let ind -= (s:is_case_label(pine, lnum) && s:is_case_ended(pine) ?
             \ 0 : s:indent_value('case-statements')) +
             \ s:indent_value('case-labels')
    if s:is_case_break(pine)
      let ind += s:indent_value('case-breaks')
    endif
  elseif s:is_case_label(line, lnum)
    if s:is_case(pine)
      let ind = indent(lnum) + s:indent_value('case-labels')
    else
      let ind -= (s:is_case_label(pine, lnum) && s:is_case_ended(pine) ?
                  \ 0 : s:indent_value('case-statements')) -
                  \ s:indent_value('case-breaks')
    endif
  elseif s:is_case_break(line)
    let ind -= s:indent_value('case-breaks')
  endif

  return ind
endfunction

function! s:is_continuation_line(line)
  return a:line =~ '\%(\%(^\|[^\\]\)\\\|&&\|||\)$'
endfunction

function! s:find_continued_lnum(lnum)
  let i = a:lnum
  while i > 1 && s:is_continuation_line(getline(i - 1))
    let i -= 1
  endwhile
  return i
endfunction

function! s:is_case_label(line, pnum)
  if a:line !~ '^\s*(\=.*)'
    return 0
  endif

  if a:pnum > 0
    let pine = getline(a:pnum)
    if !(s:is_case(pine) || s:is_case_ended(pine))
      return 0
    endif
  endif

  let suffix = substitute(a:line, '^\s*(\=', "", "")
  let nesting = 0
  let i = 0
  let n = strlen(suffix)
  while i < n
    let c = suffix[i]
    let i += 1
    if c == '\\'
      let i += 1
    elseif c == '('
      let nesting += 1
    elseif c == ')'
      if nesting == 0
        return 1
      endif
      let nesting -= 1
    endif
  endwhile
  return 0
endfunction

function! s:is_case(line)
  return a:line =~ '^\s*case\>'
endfunction

function! s:is_case_break(line)
  return a:line =~ '^\s*;[;&]'
endfunction

function! s:is_case_ended(line)
  return s:is_case_break(a:line) || a:line =~ ';[;&]\s*\%(#.*\)\=$'
endfunction

function! s:is_case_empty(line)
  if a:line =~ '^\s*$' || a:line =~ '^\s*#'
    return s:is_case_empty(getline(v:lnum - 1))
  else
    return a:line =~ '^\s*case\>'
  endif
endfunction

let &cpo = s:cpo_save
unlet s:cpo_save
