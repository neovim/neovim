" Maintainer: Anmol Sethi <anmol@aubble.com>

if exists('g:loaded_man')
  finish
endif
let g:loaded_man = 1

command! -range=0 -complete=customlist,man#complete -nargs=* Man call man#open_page(v:count, v:count1, <q-mods>, <f-args>)

augroup man
  autocmd!
  autocmd BufReadCmd man://* call man#read_page(matchstr(expand('<amatch>'), 'man://\zs.*'))
augroup END
