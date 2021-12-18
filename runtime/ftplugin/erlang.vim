" Vim ftplugin file
" Language:     Erlang (http://www.erlang.org)
" Maintainer:   Csaba Hoch <csaba.hoch@gmail.com>
" Author:       Oscar Hellström <oscar@oscarh.net>
" Contributors: Ricardo Catalinas Jiménez <jimenezrick@gmail.com>
"               Eduardo Lopez (http://github.com/tapichu)
"               Arvid Bjurklint (http://github.com/slarwise)
" Last Update:  2021-Jan-08
" License:      Vim license
" URL:          https://github.com/vim-erlang/vim-erlang-runtime

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

let &l:keywordprg = get(g:, 'erlang_keywordprg', 'erl -man')

if get(g:, 'erlang_folding', 0)
  setlocal foldmethod=expr
  setlocal foldexpr=GetErlangFold(v:lnum)
  setlocal foldtext=ErlangFoldText()
endif

setlocal comments=:%%%,:%%,:%
setlocal commentstring=%%s

setlocal formatoptions+=ro

setlocal suffixesadd=.erl,.hrl

let &l:include = '^\s*-\%(include\|include_lib\)\s*("\zs\f*\ze")'
let &l:define  = '^\s*-\%(define\|record\|type\|opaque\)'

let s:erlang_fun_begin = '^\a\w*(.*$'
let s:erlang_fun_end   = '^[^%]*\.\s*\(%.*\)\?$'

if !exists('*GetErlangFold')
  function GetErlangFold(lnum)
    let lnum = a:lnum
    let line = getline(lnum)

    if line =~ s:erlang_fun_end
      return '<1'
    endif

    if line =~ s:erlang_fun_begin && foldlevel(lnum - 1) == 1
      return '1'
    endif

    if line =~ s:erlang_fun_begin
      return '>1'
    endif

    return '='
  endfunction
endif

if !exists('*ErlangFoldText')
  function ErlangFoldText()
    let line    = getline(v:foldstart)
    let foldlen = v:foldend - v:foldstart + 1
    let lines   = ' ' . foldlen . ' lines: ' . substitute(line, "[\ \t]*", '', '')
    if foldlen < 10
      let lines = ' ' . lines
    endif
    let retval = '+' . v:folddashes . lines

    return retval
  endfunction
endif

let b:undo_ftplugin = "setlocal keywordprg< foldmethod< foldexpr< foldtext<"
      \ . " comments< commentstring< formatoptions< suffixesadd< include<"
      \ . " define<"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: sw=2 et
