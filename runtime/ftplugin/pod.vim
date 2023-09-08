" Vim filetype plugin file
" Language:      Perl POD format
" Maintainer:    vim-perl <vim-perl@googlegroups.com>
" Author:        Doug Kearns <dougkearns@gmail.com>
" Homepage:      https://github.com/vim-perl/vim-perl
" Bugs/requests: https://github.com/vim-perl/vim-perl/issues
" License:       Vim License (see :help license)
" Last Change:   2023 Jul 05

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

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

function s:jumpToSection(direction)
  let flags = a:direction == "backward" ? "bsWz" : "sWz"
  if has("syntax_items")
    let skip = "synIDattr(synID(line('.'), col('.'), 1), 'name') !~# '\\<podCommand\\>'"
  else
    let skip = ""
  endif
  for i in range(v:count1)
    call search('^=\a', flags, 0, 0, skip)
  endfor
endfunction

if !exists("no_plugin_maps") && !exists("no_pod_maps")
  for s:mode in ["n", "o", "x"]
    for s:lhs in ["]]", "]["]
      execute s:mode . "noremap <silent> <buffer> " . s:lhs . " <Cmd>call <SID>jumpToSection('forward')<CR>"
      let b:undo_ftplugin .= " | silent! execute '" . s:mode . "unmap <buffer> " . s:lhs . "'"
    endfor
    for s:lhs in ["[[", "[]"]
      execute s:mode . "noremap <silent> <buffer> " . s:lhs . " <Cmd>call <SID>jumpToSection('backward')<CR>"
      let b:undo_ftplugin .= " | silent! execute '" . s:mode . "unmap <buffer> " . s:lhs . "'"
    endfor
  endfor
  unlet s:mode s:lhs
endif

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: set expandtab:
