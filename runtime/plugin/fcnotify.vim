" autocommands for starting filesystem based file watcher

augroup fcnotify
  autocmd!
  au BufRead,BufWritePost,FileWritePost,FileAppendPost * call v:lua.vim.fcnotify.start_watch(expand('<afile>'))
  au BufDelete,BufUnload,BufWritePre,FileWritePre,FileAppendPre * call v:lua.vim.fcnotify.stop_watch(expand('<afile>'))
  au FocusGained * call  v:lua.vim.fcnotify.start_notifications()
  au FocusLost * call v:lua.vim.fcnotify.stop_notifications()
augroup END
