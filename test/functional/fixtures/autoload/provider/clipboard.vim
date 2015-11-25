let g:test_clip = { '+': [''], '*': [''], }

let s:methods = {}

let g:cliplossy = 0
let g:cliperror = 0

function! s:methods.get(reg)
  if g:cliperror
    return 0
  end
  let reg = a:reg == '"' ? '+' : a:reg
  if g:cliplossy
    " behave like pure text clipboard
    return g:test_clip[reg][0]
  else
    " behave like VIMENC clipboard
    return g:test_clip[reg]
  end
endfunction

function! s:methods.set(lines, regtype, reg)
  if a:reg == '"'
    call s:methods.set(a:lines,a:regtype,'+')
    call s:methods.set(a:lines,a:regtype,'*')
    return 0
  end
  let g:test_clip[a:reg] = [a:lines, a:regtype]
endfunction


function! provider#clipboard#Call(method, args)
  return call(s:methods[a:method],a:args,s:methods)
endfunction
