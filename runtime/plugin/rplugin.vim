if exists('g:loaded_remote_plugins') || &cp
  finish
endif
let g:loaded_remote_plugins = 1
call remote#host#LoadRemotePlugins()
