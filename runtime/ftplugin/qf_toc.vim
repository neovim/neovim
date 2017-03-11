function! s:setup_toc() abort
  if get(w:, 'quickfix_title') !~# '\<TOC$' || &syntax != 'qf'
    return
  endif

  let list = getloclist(0)
  if empty(list)
    return
  endif

  let bufnr = list[0].bufnr
  setlocal modifiable
  silent %delete _
  call setline(1, map(list, 'v:val.text'))
  setlocal nomodifiable nomodified
  let &syntax = getbufvar(bufnr, '&syntax')
endfunction


augroup qf_toc
  autocmd!
  autocmd Syntax <buffer> call s:setup_toc()
augroup END
