" The Ruby provider helper
if exists('g:loaded_ruby_provider')
  finish
endif
let g:loaded_ruby_provider = 1

let s:stderr = {}
let s:job_opts = {'rpc': v:true}

function! s:job_opts.on_stderr(chan_id, data, event)
  let stderr = get(s:stderr, a:chan_id, [''])
  let last = remove(stderr, -1)
  let a:data[0] = last.a:data[0]
  call extend(stderr, a:data)
  let s:stderr[a:chan_id] = stderr
endfunction

function! provider#ruby#Detect() abort
  if exists("g:ruby_host_prog")
    return g:ruby_host_prog
  else
    return exepath('neovim-ruby-host')
  end
endfunction

function! provider#ruby#Prog()
  return s:prog
endfunction

function! provider#ruby#Require(host) abort
  let prog = provider#ruby#Prog()
  let ruby_plugins = remote#host#PluginsForHost(a:host.name)

  for plugin in ruby_plugins
    let prog .= " " . shellescape(plugin.path)
  endfor

  try
    let channel_id = jobstart(prog, s:job_opts)
    if rpcrequest(channel_id, 'poll') ==# 'ok'
      return channel_id
    endif
  catch
    echomsg v:throwpoint
    echomsg v:exception
    for row in get(s:stderr, channel_id, [])
      echomsg row
    endfor
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
  let s:err = 'Cannot find the neovim RubyGem. Try :checkhealth'
endif

call remote#host#RegisterClone('legacy-ruby-provider', 'ruby')
call remote#host#RegisterPlugin('legacy-ruby-provider', s:plugin_path, [])
