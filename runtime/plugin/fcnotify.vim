" autocommands for starting filesystem based file watcher

" If fcnotify == off
if &filechangenotify ==# "off"
  augroup fcnotify
    autocmd!
    au OptionSet filechangenotify call v:lua.vim.fcnotify.handle_option_set(v:option_type, v:option_new)
  augroup END
else
  augroup fcnotify
    autocmd!
    au BufRead,BufWritePost,FileWritePost,FileAppendPost * call v:lua.vim.fcnotify.start_watching_buf(expand("<abuf>"))
    au BufDelete,BufUnload,BufWritePre,FileWritePre,FileAppendPre * call v:lua.vim.fcnotify.stop_watching_buf(expand("<abuf>"))
    au FocusGained * call  v:lua.vim.fcnotify.handle_focus_gained()
    au FocusLost * call v:lua.vim.fcnotify.handle_focus_lost()
    au OptionSet filechangenotify call v:lua.vim.fcnotify.handle_option_set(v:option_type, v:option_new)
  augroup END
endif
