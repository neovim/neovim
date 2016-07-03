" The Ruby provider helper
if exists('g:loaded_ruby_provider')
  finish
endif
let g:loaded_ruby_provider = 1

function! provider#ruby#Detect() abort
  return exepath('neovim-ruby-host')
endfunction

function! provider#ruby#Prog()
  return s:prog
endfunction

function! provider#ruby#Require(host) abort
  let args = []
  let ruby_plugins = remote#host#PluginsForHost(a:host.name)

  for plugin in ruby_plugins
    call add(args, plugin.path)
  endfor

  try
    let channel_id = rpcstart(provider#ruby#Prog(), args)
    if rpcrequest(channel_id, 'poll') ==# 'ok'
      return channel_id
    endif
  catch
    echomsg v:throwpoint
    echomsg v:exception
  endtry
  throw remote#host#LoadErrorForHost(a:host.orig_name, '$NVIM_RUBY_LOG_FILE')
endfunction

function! provider#ruby#Call(method, args)
  if s:err != ''
    echoerr s:err
    return
  endif

  if !exists('s:host')
    try
      let s:host = remote#host#Require('legacy-ruby-provider')
    catch
      let s:err = v:exception
      echohl WarningMsg
      echomsg v:exception
      echohl None
      return
    endtry
  endif
  return call('rpcrequest', insert(insert(a:args, 'ruby_'.a:method), s:host))
endfunction

let s:err = ''
let s:prog = provider#ruby#Detect()
let s:plugin_path = expand('<sfile>:p:h') . '/script_host.rb'

if empty(s:prog)
  let s:err = 'Couldn''t find the neovim RubyGem. ' .
        \ 'Install it with `gem install neovim`.'
endif

call remote#host#RegisterClone('legacy-ruby-provider', 'ruby')
call remote#host#RegisterPlugin('legacy-ruby-provider', s:plugin_path, [])
