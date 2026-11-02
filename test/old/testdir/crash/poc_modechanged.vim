new
call setline(1, "hello")
autocmd ModeChanged [vV\x16]*:* q!
vnoremap <F3> <Cmd>qa!<CR>
call feedkeys("ve\<C-O>ZQ", 'xt')
quit!
