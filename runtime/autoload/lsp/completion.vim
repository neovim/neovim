
""
" Omni completion with LSP
function! lsp#completion#omni(findstart, base) abort
  if a:findstart
    return col('.')
  else
    return lsp#request('textDocument/completion')
  endif
endfunction
