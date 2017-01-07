if exists('g:loaded_remote_plugins')
  finish
endif
let g:loaded_remote_plugins = 1

command! UpdateRemotePlugins call remote#host#UpdateRemotePlugins()

call remote#host#LoadRemotePlugins()

"augroup nvim-rplugin
"  autocmd!
"  autocmd FuncUndefined *
"        \ call remote#host#LoadRemotePluginsEvent(
"        \   'FuncUndefined', expand('<amatch>'))
"  autocmd CmdUndefined *
"        \ call remote#host#LoadRemotePluginsEvent(
"        \   'CmdUndefined', expand('<amatch>'))
"augroup END
