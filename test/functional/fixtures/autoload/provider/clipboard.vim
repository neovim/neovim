let g:loaded_clipboard_provider = 2

let g:test_clip = { '+': [''], '*': [''], }

let s:methods = {}

let g:cliplossy = 0
let g:cliperror = 0

" Count how many times the clipboard was invoked.
let g:clip_called_get = 0
let g:clip_called_set = 0

function! s:methods.get(reg)
  let g:clip_called_get += 1

  if g:cliperror
    return 0
  end
  if g:cliplossy
    " behave like pure text clipboard
    return g:test_clip[a:reg][0]
  else
    " behave like VIMENC clipboard
    return g:test_clip[a:reg]
  end
endfunction

function! s:methods.set(lines, regtype, reg)
  let g:clip_called_set += 1

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
