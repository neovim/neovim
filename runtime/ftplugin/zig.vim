" Vim filetype plugin file
" Language: Zig
" Upstream: https://github.com/ziglang/zig.vim

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif

let b:did_ftplugin = 1

let s:cpo_orig = &cpo
set cpo&vim

compiler zig_build

" Match Zig builtin fns
setlocal iskeyword+=@-@

" Recomended code style, no tabs and 4-space indentation
setlocal expandtab
setlocal tabstop=8
setlocal softtabstop=4
setlocal shiftwidth=4

setlocal formatoptions-=t formatoptions+=croql

setlocal suffixesadd=.zig,.zir

if has('comments')
    setlocal comments=:///,://!,://,:\\\\
    setlocal commentstring=//\ %s
endif

if has('find_in_path')
    let &l:includeexpr='substitute(v:fname, "^([^.])$", "\1.zig", "")'
    let &l:include='\v(\@import>|\@cInclude>|^\s*\#\s*include)'
endif

let &l:define='\v(<fn>|<const>|<var>|^\s*\#\s*define)'

if !exists('g:zig_std_dir') && exists('*json_decode') && executable('zig')
    silent let s:env = system('zig env')
    if v:shell_error == 0
        let g:zig_std_dir = json_decode(s:env)['std_dir']
    endif
    unlet! s:env
endif

if exists('g:zig_std_dir')
    let &l:path = &l:path . ',' . g:zig_std_dir
endif

let b:undo_ftplugin =
    \ 'setl isk< et< ts< sts< sw< fo< sua< mp< com< cms< inex< inc< pa<'

augroup vim-zig
    autocmd! * <buffer>
    autocmd BufWritePre <buffer> if get(g:, 'zig_fmt_autosave', 1) | call zig#fmt#Format() | endif
augroup END

let b:undo_ftplugin .= '|au! vim-zig * <buffer>'

let &cpo = s:cpo_orig
unlet s:cpo_orig
" vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab
