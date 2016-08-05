" Maintainer: Anmol Sethi <anmol@aubble.com>

if exists('g:loaded_man')
  finish
endif
let g:loaded_man = 1

command! -count=0 -complete=customlist,man#complete -nargs=* Man call man#open_page_command(v:count, v:count1, <f-args>)

nnoremap <silent> <Plug>(Man) :<C-U>call man#open_page_mapping(v:count, v:count1, &filetype ==# 'man' ? expand('<cWORD>') : expand('<cword>'))<CR>
