if exists('g:loaded_perl_provider')
  finish
endif

function! provider#perl#Call(method, args) abort
  return v:lua.vim.provider.perl.call(a:method, a:args)
endfunction

function! provider#perl#Require(host) abort
  return v:lua.vim.provider.perl.require(a:host, s:prog)
endfunction

let s:prog = v:lua.vim.provider.perl.detect()
let g:loaded_perl_provider = empty(s:prog) ? 1 : 2
call v:lua.require'vim.provider.perl'.start()
