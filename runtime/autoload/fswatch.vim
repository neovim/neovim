if exists('g:loaded_watcher_provider')
  finish
endif

let s:save_cpo = &cpo " save user coptions
set cpo&vim " reset them to vim defaults

command! -nargs=1 Watch call fswatch#watch_file(expand('<args>'))
command! -nargs=1 Stop call fswatch#stop_watch(expand('<args>'))

" function to prompt the user for a reload
function! fswatch#PromptReload()
  let choice = confirm("File changed. Would you like to reload?", "&Yes\n&No", 1)
  if choice == 1
    edit!
  endif
endfunction

function! fswatch#PrintWatchers()
  call luaeval("vim.fswatch.print_all()")
endfunction

function! fswatch#watch_file(fname)
  call luaeval("vim.fswatch.watch(_A)", a:fname)
endfunction

function! fswatch#stop_watch(fname)
  call luaeval("vim.fswatch.stop_watch(_A)", a:fname)
endfunction

function! fswatch#pause_notif()
  call luaeval("vim.fswatch.pause_notif_all()")
endfunction

function! fswatch#resume_notif()
  call luaeval("vim.fswatch.resume_notif_all()")
endfunction

let &cpo = s:save_cpo " restore user coptions
unlet s:save_cpo

let g:loaded_watcher_provider = 1
