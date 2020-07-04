" autocommands for starting filesystem based file watcher

if exists("did_fswatch_on")
  finish
endif
let did_fswatch_on = 1

augroup fswatch
  autocmd!
  au BufRead,BufWritePost * call fswatch#watch_file(expand('<afile>'))
  au BufDelete,BufUnload,BufWritePre * call fswatch#stop_watch(expand('<file>'))
  au FocusLost * call fswatch#pause_notif()
  au FocusGained * call fswatch#resume_notif()
augroup END
