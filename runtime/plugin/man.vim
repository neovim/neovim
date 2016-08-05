" Maintainer: Anmol Sethi <anmol@aubble.com>

if exists('g:loaded_man')
  finish
endif
let g:loaded_man = 1

command! -complete=customlist,man#complete -nargs=* Man call man#open_page_command(<f-args>)

nnoremap <silent> <Plug>(Man) :<C-U>call man#open_page_mapping(v:count, v:count1, expand('<cWORD>'))<CR>
