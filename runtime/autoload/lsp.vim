let s:client_string = "require('lsp.plugin').client"

let s:filetypes_initialized = get(s:, 'filetypes_initialized', {})
function! s:initialize_autocmds(ftype) abort
  if has_key(s:filetypes_initialized, a:ftype)
    return
  endif

  let s:filetypes_initialized[a:ftype] = 1

  augroup LanguageSeverProtocol
    " autocmd BufWritePost
  augroup END
endfunction

" TODO(tjdevries): Add non-default arguments
function! lsp#start() abort
  return luaeval(s:client_string . ".start().name")
endfunction

" TODO(tjdevries): Make sure this works correctly
" TODO(tjdevries): Figure out how to call a passed callback
function! lsp#request(request, ...) abort
  let arguments = get(a:000, 0, {})
  let optional_callback = get(a:000, 1, v:null)
  let server = get(a:000, 2, v:null)

  let result = luaeval(s:client_string . '.request(_A.request, _A.arguments, _A.callback, _A.server)', {
          \ 'request': a:request,
          \ 'args': arguments,
          \ 'callback': optional_callback,
          \ 'server': server,
        \ })

  return result
endfunction
