" autocommands for starting filesystem based file watcher

augroup autoread
    autocmd!
    au BufRead,BufWritePost,FileWritePost,FileAppendPost * call v:lua.vim._watch.start(expand("<abuf>"))
    au BufDelete,BufUnload,BufWritePre,FileWritePre,FileAppendPre * call v:lua.vim._watch.stop(expand("<abuf>"))
augroup END