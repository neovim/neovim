" Maintainer: Anmol Sethi <anmol@aubble.com>

if exists('g:loaded_man')
  finish
endif
let g:loaded_man = 1

command! -count=0 -complete=customlist,man#complete -nargs=* Man call man#open_page(v:count, v:count1, <f-args>)

nnoremap <silent> <Plug>(Man) :<C-U>call man#open_page(v:count, v:count1, &filetype ==# 'man' ? expand('<cWORD>') : expand('<cword>'))<CR>

augroup man
  autocmd!
  autocmd BufReadCmd man://* call man#read_page(matchstr(expand('<amatch>'), 'man://\zs.*'))
  " Need this because without it, if you do ':Man printf(3)' and then later,
  " open a session that contains a buffer named 'man://printf(3)', the buffer
  " will become listed.
  autocmd BufEnter man://* set nobuflisted
augroup END
