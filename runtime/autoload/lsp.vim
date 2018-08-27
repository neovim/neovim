try
  " Try and load the LSP API.
  lua require('lsp.api')
catch
  echom 'Language Server Protocol is currently not able to run.'
  finish
endtry

" TODO: Should make it easer to use the API without returning the result and
" writing hard strings
function! lsp#api_exec(method_format, ...) abort
  let printf_arguments = []
  if a:0 > 0
    let printf_arguments = a:000
  endif

  echo function('printf', ['lua vim.lsp.' . a:method_format] + printf_arguments)()
endfunction

let s:client_string = "require('lsp.plugin').client"

function! lsp#start(...) abort
  let start_filetype = get(a:000, 0, &filetype)
  let force = get(a:000, 1, v:false)

  if force || !luaeval(s:client_string . '.has_started(_A)', start_filetype)
    call luaeval(s:client_string . '.start(nil, _A).name', start_filetype)
    " call lsp#api_exec('client.start(nil, "%s")', start_filetype)
  else
    echom '[LSP] Client for ' . start_filetype . ' has already started'
  endif
endfunction

" TODO(tjdevries): Make sure this works correctly
" TODO(tjdevries): Figure out how to call a passed callback
function! lsp#request(request, ...) abort
  let arguments = get(a:000, 0, {})
  let optional_callback = get(a:000, 1, v:null)
  let filetype = get(a:000, 2, v:null)

  let request_id = luaeval(s:client_string . '.request(_A.request, _A.arguments, _A.callback, _A.filetype)', {
          \ 'request': a:request,
          \ 'arguments': arguments,
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
          \ 'arguments': arguments,
          \ 'callback': optional_callback,
          \ 'filetype': filetype,
        \ })

  return result
endfunction

""
" Give access to the default client callbacks to perform
" LSP type actions, without a server
function! lsp#handle(request, data, ...) abort abort
  let file_type = get(a:000, 0, &filetype)
  let default_only = get(a:000, 1, v:true)

  " and then calls it with the provided data
  return luaeval(s:client_string . '.handle(_A.filetype, _A.method, _A.data, _A.default_only)', {
        \ 'filetype': file_type,
        \ 'method': a:request,
        \ 'data': a:data,
        \ 'default_only': default_only,
        \ })
endfunction
