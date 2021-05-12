" The Ruby provider helper
if exists('g:loaded_ruby_provider')
  finish
endif
let g:loaded_ruby_provider = 1

function! provider#ruby#Detect() abort
  let e = empty(s:prog) ? 'missing ruby or ruby-host' : ''
  return [s:prog, e]
endfunction

function! provider#ruby#Prog() abort
  return s:prog
endfunction

function! provider#ruby#Require(host) abort
  let prog = provider#ruby#Prog()
  let ruby_plugins = remote#host#PluginsForHost(a:host.name)

  for plugin in ruby_plugins
    let prog .= " " . shellescape(plugin.path)
  endfor

  return provider#Poll(prog, a:host.orig_name, '$NVIM_RUBY_LOG_FILE')
endfunction

function! provider#ruby#Call(method, args) abort
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

function! s:detect()
  if exists("g:ruby_host_prog")
    return expand(g:ruby_host_prog, v:true)
  elseif has('win32')
    return exepath('neovim-ruby-host.bat')
  else
    let p = exepath('neovim-ruby-host')
    if empty(p)
      return ''
    endif
    " neovim-ruby-host could be an rbenv shim for another Ruby version.
    call system(p)
    return v:shell_error ? '' : p
  end
endfunction

let s:err = ''
let s:prog = s:detect()
let s:plugin_path = expand('<sfile>:p:h') . '/script_host.rb'
let g:loaded_ruby_provider = empty(s:prog) ? 1 : 2

if g:loaded_ruby_provider != 2
  let s:err = 'Cannot find the neovim RubyGem. Try :checkhealth'
endif

call remote#host#RegisterClone('legacy-ruby-provider', 'ruby')
call remote#host#RegisterPlugin('legacy-ruby-provider', s:plugin_path, [])
