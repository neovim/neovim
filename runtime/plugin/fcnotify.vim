" autocommands for starting filesystem based file watcher

augroup fcnotify
  autocmd!
  au BufRead,BufWritePost,FileWritePost,FileAppendPost * call v:lua.vim.fcnotify.start_watch(expand('<afile>'))
  au BufDelete,BufUnload,BufWritePre,FileWritePre,FileAppendPre * call v:lua.vim.fcnotify.stop_watch(expand('<afile>'))
  au FocusLost * call  v:lua.vim.fcnotify.start_notifcations()
  au FocusGained * call v:lua.vim.fcnotify.stop_notifications()
  au VimLeave * call v:lua.vim.fcnotify.quit()
augroup END
