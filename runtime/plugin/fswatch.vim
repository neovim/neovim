" autocommands for starting filesystem based file watcher

echom 'Loaded file watcher'

augroup fswatch
  autocmd!
  au BufRead,BufWritePost * call v:lua.vim.fswatch.start_watch(expand('<afile>'))
  au BufDelete,BufUnload,BufWritePre * call v:lua.vim.fswatch.stop_watch(expand('<afile>'))
  au FocusLost * call  v:lua.vim.fswatch.pause_notif_all()
  au FocusGained * call v:lua.vim.fswatch.resume_notif_all()
  au TextChanged * call v:lua.vim.fswatch.set_changed(expand('<afile>'))
augroup END
