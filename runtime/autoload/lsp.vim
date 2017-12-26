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
  let filetype = get(a:000, 2, v:null)

  let request_id = luaeval(s:client_string . '.request(_A.request, _A.arguments, _A.callback, _A.filetype)', {
          \ 'request': a:request,
          \ 'args': arguments,
          \ 'callback': optional_callback,
          \ 'filetype': filetype,
        \ })

  return request_id

  while v:true
    let result = luaeval(s:client_string . '.wait_request(_A.request_id)', {'request_id': request_id})

    if type(result) != type(v:null)
      return result
    endif

    sleep 10m
  endwhile
endfunction

""
" Async request to the lsp server.
"
" Do not wait until completion
function! lsp#request_async(request, ...) abort
  let arguments = get(a:000, 0, {})
  let optional_callback = get(a:000, 1, v:null)
  let filetype = get(a:000, 2, v:null)

  let result = luaeval(s:client_string . '.request_async(_A.request, _A.arguments, _A.callback, _A.filetype)', {
          \ 'request': a:request,
          \ 'args': arguments,
          \ 'callback': optional_callback,
          \ 'filetype': filetype,
        \ })

  return result
endfunction

""
" Give access to the default client callbacks to perform
" LSP type actions, without a server
function! lsp#handle(request, data) abort abort
  " Gets the default callback,
  " and then calls it with the provided data
  return luaeval(s:client_string . '.get_callback(_A.name)(true, _A.data)', {
        \ 'name': a:request,
        \ 'data': a:data,
        \ })
endfunction
