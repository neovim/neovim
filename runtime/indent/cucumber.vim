" Vim indent file
" Language:	Cucumber
" Maintainer:	Tim Pope <vimNOSPAM@tpope.org>
" Last Change:	2013 May 30

if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal autoindent
setlocal indentexpr=GetCucumberIndent()
setlocal indentkeys=o,O,*<Return>,<:>,0<Bar>,0#,=,!^F

let b:undo_indent = 'setl ai< inde< indk<'

" Only define the function once.
if exists("*GetCucumberIndent")
  finish
endif

function! s:syn(lnum)
  return synIDattr(synID(a:lnum,1+indent(a:lnum),1),'name')
endfunction

function! GetCucumberIndent()
  let line  = getline(prevnonblank(v:lnum-1))
  let cline = getline(v:lnum)
  let nline = getline(nextnonblank(v:lnum+1))
  let syn = s:syn(prevnonblank(v:lnum-1))
  let csyn = s:syn(v:lnum)
  let nsyn = s:syn(nextnonblank(v:lnum+1))
  if csyn ==# 'cucumberFeature' || cline =~# '^\s*Feature:'
    " feature heading
    return 0
  elseif csyn ==# 'cucumberExamples' || cline =~# '^\s*\%(Examples\|Scenarios\):'
    " examples heading
    return 2 * &sw
  elseif csyn =~# '^cucumber\%(Background\|Scenario\|ScenarioOutline\)$' || cline =~# '^\s*\%(Background\|Scenario\|Scenario Outline\):'
    " background, scenario or outline heading
    return &sw
  elseif syn ==# 'cucumberFeature' || line =~# '^\s*Feature:'
    " line after feature heading
    return &sw
  elseif syn ==# 'cucumberExamples' || line =~# '^\s*\%(Examples\|Scenarios\):'
    " line after examples heading
    return 3 * &sw
  elseif syn =~# '^cucumber\%(Background\|Scenario\|ScenarioOutline\)$' || line =~# '^\s*\%(Background\|Scenario\|Scenario Outline\):'
    " line after background, scenario or outline heading
    return 2 * &sw
  elseif cline =~# '^\s*[@#]' && (nsyn == 'cucumberFeature' || nline =~# '^\s*Feature:' || indent(prevnonblank(v:lnum-1)) <= 0)
    " tag or comment before a feature heading
    return 0
  elseif cline =~# '^\s*@'
    " other tags
    return &sw
  elseif cline =~# '^\s*[#|]' && line =~# '^\s*|'
    " mid-table
    " preserve indent
    return indent(prevnonblank(v:lnum-1))
  elseif cline =~# '^\s*|' && line =~# '^\s*[^|]'
    " first line of a table, relative indent
    return indent(prevnonblank(v:lnum-1)) + &sw
  elseif cline =~# '^\s*[^|]' && line =~# '^\s*|'
    " line after a table, relative unindent
    return indent(prevnonblank(v:lnum-1)) - &sw
  elseif cline =~# '^\s*#' && getline(v:lnum-1) =~ '^\s*$' && (nsyn =~# '^cucumber\%(Background\|Scenario\|ScenarioOutline\)$' || nline =~# '^\s*\%(Background\|Scenario\|Scenario Outline\):')
    " comments on scenarios
    return &sw
  endif
  return indent(prevnonblank(v:lnum-1))
endfunction

" vim:set sts=2 sw=2:
