if exists('loaded_external_plugins') || &cp
  finish
endif
let loaded_external_plugins = 1
call rpc#host#LoadExternalPlugins()
