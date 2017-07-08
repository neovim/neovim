if exists("g:loaded_help")
  finish
endif
let g:loaded_help = 1

function! help#topic() abort
  let col = col('.') - 1
  while col && getline('.')[col] =~# '\k'
    let col -= 1
  endwhile

  let pre = col == 0 ? '' : getline('.')[0 : col]
  let col = col('.') - 1
  while col && getline('.')[col] =~# '\k'
    let col += 1
  endwhile

  let post = getline('.')[col : -1]
  let syn = synIDattr(synID(line('.'), col('.'), 1), 'name')
  let cword = expand('<cword>')
  if syn ==# 'vimFuncName' && post ==# '('
    return cword . '()'
  elseif syn ==# 'vimOption'
    return "'" . cword . "'"
  elseif pre =~# '&$' || pre =~# '&[lg]:$'
    return "'" . cword . "'"
  elseif pre =~# 'set\s\+$' || pre =~# '\vsetl(ocal)?\s+$' || pre =~# '\vsetg(lobal)?\s+$'
    return "'" . cword . "'"
  elseif syn ==# 'vimUserAttrbKey'
    return ':command-' . cword
  elseif pre =~# '^\s*:\=$'
    return ':' . cword
  elseif pre =~# '\<[vgbtw]:$'
    return 'v:' . cword
  elseif cword ==# '[vgbtw]' && post =~# ':\w\+'
    return 'v' . matchstr(post, ':\w\+')
  else
    return cword
  endif
endfunction
