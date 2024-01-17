" Vim filetype plugin file
" Language: gdscript (Godot game engine scripting language)
" Maintainer: Maxim Kim <habamax@gmail.com>
" Website: https://github.com/habamax/vim-gdscript
"
" This file has been manually translated from Vim9 script.

if exists("b:did_ftplugin") | finish | endif

let s:save_cpo = &cpo
set cpo&vim

let b:did_ftplugin = 1
let b:undo_ftplugin = 'setlocal cinkeys<'
      \ .. '| setlocal indentkeys<'
      \ .. '| setlocal commentstring<'
      \ .. '| setlocal suffixesadd<'
      \ .. '| setlocal foldexpr<'
      \ .. '| setlocal foldignore<'

setlocal cinkeys-=0#
setlocal indentkeys-=0#
setlocal suffixesadd=.gd
setlocal commentstring=#\ %s
setlocal foldignore=
setlocal foldexpr=s:GDScriptFoldLevel()


function s:GDScriptFoldLevel() abort
    let line = getline(v:lnum)
    if line =~? '^\s*$'
        return "-1"
    endif

    let sw = shiftwidth()
    let indent = indent(v:lnum) / sw
    let indent_next = indent(nextnonblank(v:lnum + 1)) / sw

    if indent_next > indent && line =~# ':\s*$'
        return $">{indent_next}"
    else
        return $"{indent}"
    endif
endfunction


if !exists("g:no_plugin_maps")
    " Next/Previous section
    function s:NextSection(back, cnt) abort
        for n in range(a:cnt)
            call search('^\s*func\s', a:back ? 'bW' : 'W')
        endfor
    endfunction

    " Nvim: <scriptcmd> hasn't been ported yet.
    " nnoremap <silent><buffer> ]] <scriptcmd>NextSection(false, v:count1)<CR>
    " nnoremap <silent><buffer> [[ <scriptcmd>NextSection(true, v:count1)<CR>
    nnoremap <silent><buffer> ]] <Cmd>call <SID>NextSection(v:false, v:count1)<CR>
    nnoremap <silent><buffer> [[ <Cmd>call <SID>NextSection(v:true, v:count1)<CR>
    xmap <buffer><expr> ]] $'<C-\><C-N>{v:count1}]]m>gv'
    xmap <buffer><expr> [[ $'<C-\><C-N>{v:count1}[[m>gv'
    let b:undo_ftplugin ..=
          \    " | silent exe 'unmap <buffer> [['"
          \ .. " | silent exe 'unmap <buffer> ]]'"
endif

let &cpo = s:save_cpo
unlet s:save_cpo
