" Vim indent file
" Language:	Cucumber
" Maintainer:	Tim Pope <vimNOSPAM@tpope.org>
" Last Change:	2023 Dec 28
" 2025 Apr 16 by Vim Project (set 'cpoptions' for line continuation, #17121)

if exists("b:did_indent")
  finish
endif
let b:did_indent = 1
let s:cpo_save = &cpo
set cpo&vim

setlocal autoindent
setlocal indentexpr=GetCucumberIndent()
setlocal indentkeys=o,O,*<Return>,<:>,0<Bar>,0#,=,!^F

let b:undo_indent = 'setl ai< inde< indk<'

" Only define the function once.
if exists("*GetCucumberIndent")
  finish
endif

let s:headings = {
      \ 'Feature': 'feature',
      \ 'Rule': 'rule',
      \ 'Background': 'bg_or_scenario',
      \ 'Scenario': 'bg_or_scenario',
      \ 'ScenarioOutline': 'bg_or_scenario',
      \ 'Examples': 'examples',
      \ 'Scenarios': 'examples'}

function! s:Line(lnum) abort
  if getline(a:lnum) =~# ':'
    let group = matchstr(synIDattr(synID(a:lnum,1+indent(a:lnum), 1), 'name'), '^cucumber\zs.*')
    if !has_key(s:headings, group)
      let group = substitute(matchstr(getline(a:lnum), '^\s*\zs\%([^:]\+\)\ze:\S\@!'), '\s\+', '', 'g')
    endif
  else
    let group = ''
  endif
  let char = matchstr(getline(a:lnum), '^\s*\zs[[:punct:]]')
  return {
        \ 'lnum': a:lnum,
        \ 'indent': indent(a:lnum),
        \ 'heading': get(s:headings, group, ''),
        \ 'tag': char ==# '@',
        \ 'table': char ==# '|',
        \ 'comment': char ==# '#',
        \ }
endfunction

function! GetCucumberIndent(...) abort
  let lnum = a:0 ? a:1 : v:lnum
  let sw = shiftwidth()
  let prev = s:Line(prevnonblank(lnum-1))
  let curr = s:Line(lnum)
  let next = s:Line(nextnonblank(lnum+1))
  if curr.heading ==# 'feature'
    " feature heading
    return 0
  elseif curr.heading ==# 'examples'
    " examples heading
    return 2 * sw
  elseif curr.heading ==# 'bg_or_scenario'
    " background, scenario or outline heading
    return sw
  elseif prev.heading ==# 'feature'
    " line after feature heading
    return sw
  elseif prev.heading ==# 'examples'
    " line after examples heading
    return 3 * sw
  elseif prev.heading ==# 'bg_or_scenario'
    " line after background, scenario or outline heading
    return 2 * sw
  elseif (curr.tag || curr.comment) && (next.heading ==# 'feature' || prev.indent <= 0)
    " tag or comment before a feature heading
    return 0
  elseif curr.tag
    " other tags
    return sw
  elseif (curr.table || curr.comment) && prev.table
    " mid-table
    " preserve indent
    return prev.indent
  elseif curr.table && !prev.table
    " first line of a table, relative indent
    return prev.indent + sw
  elseif !curr.table && prev.table
    " line after a table, relative unindent
    return prev.indent - sw
  elseif curr.comment && getline(v:lnum-1) =~# '^\s*$' && next.heading ==# 'bg_or_scenario'
    " comments on scenarios
    return sw
  endif
  return prev.indent < 0 ? 0 : prev.indent
endfunction

let &cpo = s:cpo_save
unlet s:cpo_save

" vim:set sts=2 sw=2:
