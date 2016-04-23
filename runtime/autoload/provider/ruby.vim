" The Ruby provider helper
if exists('s:loaded_ruby_provider')
  finish
endif

let s:loaded_ruby_provider = 1

function! provider#ruby#Require(host) abort
  " Collect registered Ruby plugins into args
  let args = []
  let ruby_plugins = remote#host#PluginsForHost(a:host.name)

  for plugin in ruby_plugins
    call add(args, plugin.path)
  endfor

  try
    let channel_id = rpcstart(provider#ruby#Prog(), args)

    if rpcrequest(channel_id, 'poll') == 'ok'
      return channel_id
    endif
  catch
    echomsg v:throwpoint
    echomsg v:exception
  endtry

  throw remote#host#LoadErrorForHost(a:host.orig_name,
        \ '$NVIM_RUBY_LOG_FILE')
endfunction

function! provider#ruby#Prog() abort
  return 'neovim-ruby-host'
endfunction
