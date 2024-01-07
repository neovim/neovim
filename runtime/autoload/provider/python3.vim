if exists('g:loaded_python3_provider')
  finish
endif

function! provider#python3#Call(method, args) abort
  return v:lua.require'vim.provider.python'.call(a:method, a:args)
endfunction

function! provider#python3#Require(host) abort
  return v:lua.require'vim.provider.python'.require(a:host)
endfunction

let s:prog = v:lua.require'vim.provider.python'.detect_by_module('neovim')
let g:loaded_python3_provider = empty(s:prog) ? 1 : 2
call v:lua.require'vim.provider.python'.start()
