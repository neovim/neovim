let s:client_string = "require('lsp.plugin').client"

let s:autocmds_initialized = get(s:, 'autocmds_initialized ', v:false)
function! s:initialize_autocmds() abort
  if s:autocmds_initialized
    return
  endif

  let s:autocmds_initialized = v:true

  augroup LanguageSeverProtocol
    autocmd!
    call luaeval('require("lsp.autocmds").export_autocmds()')
  augroup END

endfunction

" TODO(tjdevries): Add non-default arguments
function! lsp#start() abort
  call s:initialize_autocmds()

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
