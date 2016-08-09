if exists('b:did_ftplugin')
  finish
endif

let b:did_ftplugin = 1

setlocal keywordprg=:help

nnoremap <silent><buffer> q :close<cr>
nnoremap <silent><buffer> gf :<c-u>call msgpane#goto()<cr>
