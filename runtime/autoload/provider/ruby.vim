" The Ruby provider helper
if exists('g:loaded_ruby_provider')
  finish
endif
let g:loaded_ruby_provider = 1

let s:stderr = {}
let s:job_opts = {'rpc': v:true}

function! s:job_opts.on_stderr(chan_id, data, event) dict
  let stderr = get(s:stderr, a:chan_id, [''])
  let last = remove(stderr, -1)
  let a:data[0] = last.a:data[0]
  call extend(stderr, a:data)
  let s:stderr[a:chan_id] = stderr
endfunction

function! s:job_opts.on_exit(chan_id, code, event) dict abort
  if a:code == 0 | return | endif
  echoerr 'Ruby provider exited with code '.a:code
  for row in get(s:stderr, a:chan_id, [])
    echoerr row
  endfor
  unlet s:stderr[a:chan_id]
  "throw remote#host#LoadErrorForHost('ruby', '$NVIM_RUBY_LOG_FILE')
endfunction

function! provider#ruby#Detect() abort
  return exepath('neovim-ruby-host')
endfunction

function! provider#ruby#Prog()
  return s:prog
endfunction

function! provider#ruby#Require(host) abort
  let args = [provider#ruby#Prog()]
  let ruby_plugins = remote#host#PluginsForHost(a:host.name)

  for plugin in ruby_plugins
    call add(args, plugin.path)
  endfor

  let channel_id = jobstart(args, s:job_opts)

  if channel_id == -1
    echoerr args[0] . ' is not executable. Try :CheckHealth'
  endif

  return channel_id
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
  let s:err = 'Cannot find the neovim RubyGem. Try :CheckHealth'
endif

call remote#host#RegisterClone('legacy-ruby-provider', 'ruby')
call remote#host#RegisterPlugin('legacy-ruby-provider', s:plugin_path, [])
