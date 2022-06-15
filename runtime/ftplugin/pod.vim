" Vim filetype plugin file
" Language:      Perl POD format
" Maintainer:    vim-perl <vim-perl@googlegroups.com>
" Author:        Doug Kearns <dougkearns@gmail.com>
" Homepage:      https://github.com/vim-perl/vim-perl
" Bugs/requests: https://github.com/vim-perl/vim-perl/issues
" License:       Vim License (see :help license)
" Last Change:   2021 Oct 19

if exists("b:did_ftplugin")
    finish
endif

let s:save_cpo = &cpo
set cpo-=C

setlocal comments=fb:=for\ comment
setlocal commentstring==for\ comment\ %s

let b:undo_ftplugin = "setl com< cms<"

if exists("loaded_matchit") && !exists("b:match_words")
  let b:match_words =
        \ '^=pod\>:^=cut\>,' .
        \ '^=begin\s\+\(\S\+\):^=end\s\+\1,' .
        \ '^=over\>:^=item\>:^=back\>,' .
        \ '[IBCLEFSXZ]<<\%(\s\+\|$\)\@=:\%(\s\+\|^\)\@<=>>,' .
        \ '[IBCLEFSXZ]<:>'
  let b:undo_ftplugin .= " | unlet! b:match_words"
endif

if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "POD Source Files (*.pod)\t*.pod\n" .
        \              "Perl Source Files (*.pl)\t*.pl\n" .
        \              "Perl Modules (*.pm)\t*.pm\n" .
        \              "All Files (*.*)\t*.*\n"
  let b:undo_ftplugin .= " | unlet! b:browsefilter"
endif

function! s:jumpToSection(backwards)
  let flags = a:backwards ? 'bsWz' : 'sWz'
  if has('syntax_items')
    let skip = "synIDattr(synID(line('.'), col('.'), 1), 'name') !~# '\\<podCommand\\>'"
  else
    let skip = ''
  endif
  for i in range(v:count1)
    call search('^=\a', flags, 0, 0, skip)
  endfor
endfunction

if !exists("no_plugin_maps") && !exists("no_pod_maps")
  nnoremap <silent> <buffer> ]] <Cmd>call <SID>jumpToSection()<CR>
  vnoremap <silent> <buffer> ]] <Cmd>call <SID>jumpToSection()<CR>
  nnoremap <silent> <buffer> ][ <Cmd>call <SID>jumpToSection()<CR>
  vnoremap <silent> <buffer> ][ <Cmd>call <SID>jumpToSection()<CR>
  nnoremap <silent> <buffer> [[ <Cmd>call <SID>jumpToSection(1)<CR>
  vnoremap <silent> <buffer> [[ <Cmd>call <SID>jumpToSection(1)<CR>
  nnoremap <silent> <buffer> [] <Cmd>call <SID>jumpToSection(1)<CR>
  vnoremap <silent> <buffer> [] <Cmd>call <SID>jumpToSection(1)<CR>
  let b:undo_ftplugin .=
        \ " | silent! exe 'nunmap <buffer> ]]' | silent! exe 'vunmap <buffer> ]]'" .
        \ " | silent! exe 'nunmap <buffer> ][' | silent! exe 'vunmap <buffer> ]['" .
        \ " | silent! exe 'nunmap <buffer> ]]' | silent! exe 'vunmap <buffer> ]]'" .
        \ " | silent! exe 'nunmap <buffer> []' | silent! exe 'vunmap <buffer> []'"
endif

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: set expandtab:
