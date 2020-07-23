" autocommands for starting filesystem based file watcher

set noautoread
augroup fcnotify
  autocmd!
  au BufRead,BufWritePost * call v:lua.vim.fcnotify.start_watch(expand('<afile>'))
  au BufDelete,BufUnload,BufWritePre * call v:lua.vim.fcnotify.stop_watch(expand('<afile>'))
  au FocusLost * call  v:lua.vim.fcnotify.pause_notif_all()
  au FocusGained * call v:lua.vim.fcnotify.resume_notif_all()
augroup END
