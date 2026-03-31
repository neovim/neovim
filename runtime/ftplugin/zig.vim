" Vim filetype plugin file
" Language:     Zig
" Maintainer:   Mathias Lindgren <math.lindgren@gmail.com>
" Last Change:  2024 Oct 04
" Based on:     https://github.com/ziglang/zig.vim

if exists("b:did_ftplugin")
  finish
endif

let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

" Match Zig builtin fns
setlocal iskeyword+=@-@
setlocal formatoptions-=t formatoptions+=croql
setlocal suffixesadd=.zig,.zir,.zon
let &l:define='\v(<fn>|<const>|<var>|^\s*\#\s*define)'
let b:undo_ftplugin = 'setl isk< fo< sua< mp< def<'

if get(g:, 'zig_recommended_style', 1)
    setlocal expandtab
    setlocal tabstop=8
    setlocal softtabstop=4
    setlocal shiftwidth=4
    let b:undo_ftplugin .= ' | setl et< ts< sts< sw<'
endif

if has('comments')
    setlocal comments=:///,://!,://
    setlocal commentstring=//\ %s
    let b:undo_ftplugin .= ' | setl com< cms<'
endif

if has('find_in_path')
    let &l:includeexpr='substitute(v:fname, "^([^.])$", "\1.zig", "")'
    let &l:include='\v(\@import>|\@cInclude>|^\s*\#\s*include)'
    let b:undo_ftplugin .= ' | setl inex< inc<'
endif

if exists('g:zig_std_dir')
    let &l:path .= ',' . g:zig_std_dir
    let b:undo_ftplugin .= ' | setl pa<'
endif

if !exists('current_compiler')
    compiler zig_build
    let b:undo_ftplugin .= "| compiler make"
endif

let &cpo = s:cpo_save
unlet s:cpo_save
" vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab
