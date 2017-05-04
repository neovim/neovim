let g:nvim_lsp_client = -1

function! s:get_client() abort
   return luaeval("require('lsp.plugin').client.get()")
endfunction

function! lsp#request#textdocument_references()
   " TODO
endfunction
