if exists('b:did_ftplugin')
  finish
endif

let b:did_ftplugin = 1

setlocal keywordprg=:help

nnoremap <silent><buffer> q :close<cr>
nnoremap <silent><buffer> gf :<c-u>call msgbuf#goto()<cr>

nnoremap <silent><buffer> ]] :<c-u>call search('^-- ','sW')<cr>
nnoremap <silent><buffer> [[ :<c-u>call search('^-- ','sbW')<cr>
xnoremap <silent><buffer> ]] :<c-u>execute 'normal! gv'<bar>call search('^-- ','sW')<cr>
xnoremap <silent><buffer> [[ :<c-u>execute 'normal! gv'<bar>call search('^-- ','sbW')<cr>
