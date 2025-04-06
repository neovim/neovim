" Vim autoload file.
" Language:     Hare
" Maintainer:   Amelia Clarke <selene@perilune.dev>
" Last Updated: 2024-05-10
" Upstream:     https://git.sr.ht/~sircmpwn/hare.vim

" Attempt to find the directory for a given Hare module.
function hare#FindModule(str)
  let path = substitute(trim(a:str, ':', 2), '::', '/', 'g')
  let dir = finddir(path)
  while !empty(path) && empty(dir)
    let path = substitute(path, '/\?\h\w*$', '', '')
    let dir = finddir(path)
  endwhile
  return dir
endfunction

" Return the value of HAREPATH if it exists. Otherwise use a reasonable default.
function hare#GetPath()
  if empty($HAREPATH)
    return '/usr/src/hare/stdlib,/usr/src/hare/third-party'
  endif
  return substitute($HAREPATH, ':', ',', 'g')
endfunction

" vim: et sts=2 sw=2 ts=8
