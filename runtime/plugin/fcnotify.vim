" autocommands for starting filesystem based file watcher

" If fcnotify == off
if &filechangenotify ==# "off"
  augroup fcnotify
    autocmd!
    au OptionSet filechangenotify call v:lua.vim.fcnotify.check_option(v:option_type)
  augroup END
else
  augroup fcnotify
    autocmd!
    au BufRead,BufWritePost,FileWritePost,FileAppendPost * call v:lua.vim.fcnotify.start_watch(expand("<abuf>"))
    au BufDelete,BufUnload,BufWritePre,FileWritePre,FileAppendPre * call v:lua.vim.fcnotify.stop_watch(expand("<abuf>"))
    au FocusGained * call  v:lua.vim.fcnotify.start_notifications()
    au FocusLost * call v:lua.vim.fcnotify.stop_notifications()
    au OptionSet filechangenotify call v:lua.vim.fcnotify.check_option(v:option_type)
  augroup END
endif
