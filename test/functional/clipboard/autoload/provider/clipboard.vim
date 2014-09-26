let g:test_clip = { '+': [''], '*': [''], }

let s:methods = {}

function! s:methods.get(reg)
  return g:test_clip[a:reg]
endfunction

function! s:methods.set(lines, regtype, reg)
  let g:test_clip[a:reg] = a:lines
endfunction


function! provider#clipboard#Call(method, args)
  return call(s:methods[a:method],a:args,s:methods)
endfunction
