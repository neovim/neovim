if exists('loaded_remote_plugins') || &cp
  finish
endif
let loaded_remote_plugins = 1
call remote#host#LoadRemotePlugins()
