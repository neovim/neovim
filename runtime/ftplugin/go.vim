" Vim filetype plugin file
" Language:	Go
" Maintainer:	David Barnett (https://github.com/google/vim-ft-go is archived)
" Last Change:	2014 Aug 16
" 2024 Jul 16 by Vim Project (add recommended indent style)
" 2025 Mar 07 by Vim Project (add formatprg and keywordprg option #16804)
" 2025 Mar 18 by Vim Project (use :term for 'keywordprg' #16911)
" 2025 Apr 16 by Vim Project (set 'cpoptions' for line continuation, #17121)
" 2025 Jul 02 by Vim Project (add section movement mappings #17641)

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

setlocal formatoptions-=t
setlocal formatprg=gofmt

setlocal comments=s1:/*,mb:*,ex:*/,://
setlocal commentstring=//\ %s
setlocal keywordprg=:GoKeywordPrg

command! -buffer -nargs=* GoKeywordPrg call s:GoKeywordPrg()

let b:undo_ftplugin = 'setl fo< com< cms< fp< kp<'
                  \ . '| delcommand -buffer GoKeywordPrg'

if get(g:, 'go_recommended_style', 1)
  setlocal noexpandtab softtabstop=0 shiftwidth=0
  let b:undo_ftplugin .= ' | setl et< sts< sw<'
endif

if !exists('*' . expand('<SID>') . 'GoKeywordPrg')
  func! s:GoKeywordPrg()
    let temp_isk = &l:iskeyword
    setl iskeyword+=.
    try
      let cmd = 'go doc -C ' . shellescape(expand('%:h')) . ' ' . shellescape(expand('<cword>'))
      if has('gui_running') || has('nvim')
        exe 'hor term' cmd
      else
        exe '!' . cmd
      endif
    finally
      let &l:iskeyword = temp_isk
    endtry
  endfunc
endif

if !exists("no_plugin_maps") && !exists("no_go_maps")
  noremap <silent> <buffer> ]] <Cmd>call <SID>GoFindSection('next_start', v:count1)<CR>
  noremap <silent> <buffer> ][ <Cmd>call <SID>GoFindSection('next_end', v:count1)<CR>
  noremap <silent> <buffer> [[ <Cmd>call <SID>GoFindSection('prev_start', v:count1)<CR>
  noremap <silent> <buffer> [] <Cmd>call <SID>GoFindSection('prev_end', v:count1)<CR>
  let b:undo_ftplugin .= ''
                      \ . '| unmap <buffer> ]]'
                      \ . '| unmap <buffer> ]['
                      \ . '| unmap <buffer> [['
                      \ . '| unmap <buffer> []'
endif

function! <SID>GoFindSection(dir, count)
  mark '
  let c = a:count
  while c > 0
    if a:dir == 'next_start'
      keepjumps call search('^\(type\|func\)\>', 'W')
    elseif a:dir == 'next_end'
      keepjumps call search('^}', 'W')
    elseif a:dir == 'prev_start'
      keepjumps call search('^\(type\|func\)\>', 'bW')
    elseif a:dir == 'prev_end'
      keepjumps call search('^}', 'bW')
    endif
    let c -= 1
  endwhile
endfunction

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: sw=2 sts=2 et
