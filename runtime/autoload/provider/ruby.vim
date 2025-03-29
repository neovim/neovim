if exists('g:loaded_ruby_provider')
  finish
endif

function! provider#ruby#Require(host) abort
  return v:lua.vim.provider.ruby.require(a:host)
endfunction

function! provider#ruby#Call(method, args) abort
  return v:lua.vim.provider.ruby.call(a:method, a:args)
endfunction

let s:prog = v:lua.vim.provider.ruby.detect()
let g:loaded_ruby_provider = empty(s:prog) ? 0 : 2
let s:plugin_path = expand('<sfile>:p:h') . '/script_host.rb'
call v:lua.require'vim.provider.ruby'.start(s:plugin_path)
