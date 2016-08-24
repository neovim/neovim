" Maintainer: Anmol Sethi <anmol@aubble.com>

if exists('g:loaded_man')
  finish
endif
let g:loaded_man = 1

command! -range=0 -complete=customlist,man#complete -nargs=+ Man call man#open_page(v:count, v:count1, <q-mods>, <f-args>)

function! s:cword() abort
  return &filetype ==# 'man' ? expand('<cWORD>') : expand('<cword>')
endfunction

nnoremap <silent> <Plug>(man)        :<C-U>execute 'Man '         .<SID>cword()<CR>
nnoremap <silent> <Plug>(man_vsplit) :<C-U>execute 'vertical Man '.<SID>cword()<CR>
nnoremap <silent> <Plug>(man_tab)    :<C-U>execute 'tab Man '     .<SID>cword()<CR>

augroup man
  autocmd!
  autocmd BufReadCmd man://* call man#read_page(matchstr(expand('<amatch>'), 'man://\zs.*'))
augroup END
