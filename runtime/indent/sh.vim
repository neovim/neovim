" Vim indent file
" Language:            Shell Script
" Maintainer:          Christian Brabandt <cb@256bit.org>
" Original Author:     Nikolai Weibull <now@bitwi.se>
" Previous Maintainer: Peter Aronoff <telemachus@arpinum.org>
" Latest Revision:     2019-02-02
" License:             Vim (see :h license)
" Repository:          https://github.com/chrisbra/vim-sh-indent
" Changelog:
"          20190201  - Better check for closing if sections
"          20180724  - make check for zsh syntax more rigid (needs word-boundaries)
"          20180326  - better support for line continuation
"          20180325  - better detection of function definitions
"          20180127  - better support for zsh complex commands
"          20170808: - better indent of line continuation
"          20170502: - get rid of buffer-shiftwidth function
"          20160912: - preserve indentation of here-doc blocks
"          20160627: - detect heredocs correctly
"          20160213: - detect function definition correctly
"          20160202: - use shiftwidth() function
"          20151215: - set b:undo_indent variable
"          20150728: - add foreach detection for zsh

if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal indentexpr=GetShIndent()
setlocal indentkeys+=0=then,0=do,0=else,0=elif,0=fi,0=esac,0=done,0=end,),0=;;,0=;&
setlocal indentkeys+=0=fin,0=fil,0=fip,0=fir,0=fix
setlocal indentkeys-=:,0#
setlocal nosmartindent

let b:undo_indent = 'setlocal indentexpr< indentkeys< smartindent<'

if exists("*GetShIndent")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

let s:sh_indent_defaults = {
      \ 'default': function('shiftwidth'),
      \ 'continuation-line': function('shiftwidth'),
      \ 'case-labels': function('shiftwidth'),
      \ 'case-statements': function('shiftwidth'),
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
  let curline = getline(v:lnum)
  let lnum = prevnonblank(v:lnum - 1)
  if lnum == 0
    return 0
  endif
  let line = getline(lnum)

  let pnum = prevnonblank(lnum - 1)
  let pline = getline(pnum)
  let ind = indent(lnum)

  " Check contents of previous lines
  if line =~ '^\s*\%(if\|then\|do\|else\|elif\|case\|while\|until\|for\|select\|foreach\)\>' ||
        \  (&ft is# 'zsh' && line =~ '\<\%(if\|then\|do\|else\|elif\|case\|while\|until\|for\|select\|foreach\)\>')
    if !s:is_end_expression(line)
      let ind += s:indent_value('default')
    endif
  elseif s:is_case_label(line, pnum)
    if !s:is_case_ended(line)
      let ind += s:indent_value('case-statements')
    endif
  " function definition
  elseif s:is_function_definition(line)
    if line !~ '}\s*\%(#.*\)\=$'
      let ind += s:indent_value('default')
    endif
  elseif s:is_continuation_line(line)
    if pnum == 0 || !s:is_continuation_line(pline)
      let ind += s:indent_value('continuation-line')
    endif
  elseif s:end_block(line) && !s:start_block(line)
    let ind -= s:indent_value('default')
  elseif pnum != 0 &&
        \ s:is_continuation_line(pline) &&
        \ !s:end_block(curline) &&
        \ !s:is_end_expression(curline)
    " only add indent, if line and pline is in the same block
    let i = v:lnum
    let ind2 = indent(s:find_continued_lnum(pnum))
    while !s:is_empty(getline(i)) && i > pnum
      let i -= 1
    endw
    if i == pnum
      let ind += ind2
    else
      let ind = ind2
    endif
  endif

  let pine = line
  " Check content of current line
  let line = curline
  " Current line is a endif line, so get indent from start of "if condition" line
  " TODO: should we do the same for other "end" lines?
  if curline =~ '^\s*\%(fi\)\s*\%(#.*\)\=$'
    let previous_line = search('if.\{-\};\s*then\s*\%(#.*\)\=$', 'bnW')
    if previous_line > 0
      let ind = indent(previous_line)
    endif
  elseif line =~ '^\s*\%(then\|do\|else\|elif\|done\|end\)\>' || s:end_block(line)
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
  elseif s:is_here_doc(line)
    let ind = 0
  " statements, executed within a here document. Keep the current indent
  elseif match(map(synstack(v:lnum, 1), 'synIDattr(v:val, "name")'), '\c\mheredoc') > -1
    return indent(v:lnum)
  elseif s:is_comment(line) && s:is_empty(getline(v:lnum-1))
    return indent(v:lnum)
  endif

  return ind > 0 ? ind : 0
endfunction

function! s:is_continuation_line(line)
  " Comment, cannot be a line continuation
  if a:line =~ '^\s*#'
    return 0
  else
    " start-of-line
    " \\ or && or || or |
    " followed optionally by { or #
    return a:line =~ '\%(\%(^\|[^\\]\)\\\|&&\|||\||\)' .
                 \ '\s*\({\s*\)\=\(#.*\)\=$'
  endif
endfunction

function! s:find_continued_lnum(lnum)
  let i = a:lnum
  while i > 1 && s:is_continuation_line(getline(i - 1))
    let i -= 1
  endwhile
  return i
endfunction

function! s:is_function_definition(line)
  return a:line =~ '^\s*\<\k\+\>\s*()\s*{' ||
       \ a:line =~ '^\s*{' ||
       \ a:line =~ '^\s*function\s*\w\S\+\s*\%(()\)\?\s*{'
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

function! s:is_here_doc(line)
    if a:line =~ '^\w\+$'
      let here_pat = '<<-\?'. s:escape(a:line). '\$'
      return search(here_pat, 'bnW') > 0
    endif
    return 0
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

function! s:escape(pattern)
    return '\V'. escape(a:pattern, '\\')
endfunction

function! s:is_empty(line)
  return a:line =~ '^\s*$'
endfunction

function! s:end_block(line)
  return a:line =~ '^\s*}'
endfunction

function! s:start_block(line)
  return a:line =~ '{\s*\(#.*\)\?$'
endfunction

function! s:find_start_block(lnum)
  let i = a:lnum
  while i > 1 && !s:start_block(getline(i))
    let i -= 1
  endwhile
  return i
endfunction

function! s:is_comment(line)
  return a:line =~ '^\s*#'
endfunction

function! s:is_end_expression(line)
  return a:line =~ '\<\%(fi\|esac\|done\|end\)\>\s*\%(#.*\)\=$'
endfunction

let &cpo = s:cpo_save
unlet s:cpo_save
