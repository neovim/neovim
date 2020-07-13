" autocommands for starting filesystem based file watcher

augroup fswatch
  autocmd!
  au BufRead,BufWritePost * call v:lua.vim.fswatch.start_watch(expand('<afile>'))
  au BufDelete,BufUnload,BufWritePre * call v:lua.vim.fswatch.stop_watch(expand('<afile>'))
  au FocusLost * call  v:lua.vim.fswatch.pause_notif_all()
  au FocusGained * call v:lua.vim.fswatch.resume_notif_all()
augroup END
