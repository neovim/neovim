try
  " Try and load the LSP API.
  lua require('vim.lsp')
catch
  echom 'Language Server Protocol is currently not able to run.'
  finish
endtry

let s:lsp_module = "vim.lsp"

" TODO(tjdevries): Make sure this works correctly
" TODO(tjdevries): Figure out how to call a passed callback
function! lsp#request(method, ...) abort
  let params = get(a:000, 0, {})
  let optional_callback = get(a:000, 1, v:null)
  let bufnr = get(a:000, 2, v:null)
  let filetype = get(a:000, 3, &filetype)

  let result = luaeval(s:lsp_module . '.request(_A.method, _A.params, _A.callback, _A.bufnr, _A.filetype)', {
          \ 'method': a:method,
          \ 'params': params,
          \ 'callback': optional_callback,
          \ 'bufnr': bufnr,
          \ 'filetype': filetype,
        \ })

  return result
endfunction

" Async request to the lsp server.
" Do not wait until completion
function! lsp#request_async(method, ...) abort
  let params = get(a:000, 0, {})
  let optional_callback = get(a:000, 1, v:null)
  let bufnr = get(a:000, 2, v:null)
  let filetype = get(a:000, 3, v:null)

  let result = luaeval(s:lsp_module . '.request_async(_A.method, _A.params, _A.callback, _A.bufnr, _A.filetype)', {
          \ 'method': a:method,
          \ 'params': params,
          \ 'callback': optional_callback,
          \ 'bufnr': bufnr,
          \ 'filetype': filetype,
        \ })

  return result
endfunction

" Notify to the lsp server.
function! lsp#notify(method, ...) abort
  let params = get(a:000, 0, {})
  let bufnr = get(a:000, 1, v:null)
  let filetype = get(a:000, 2, &filetype)

  luaeval(s:lsp_module . '.notify(_A.method, _A.params, _A.bufnr, _A.filetype)', {
          \ 'method': a:method,
          \ 'params': params,
          \ 'bufnr': bufnr,
          \ 'filetype': filetype,
        \ })
endfunction

" Give access to the default client callbacks to perform
" LSP type actions, without a server
function! lsp#handle(request, data, ...) abort abort
  let file_type = get(a:000, 0, &filetype)
  let default_only = get(a:000, 1, v:true)

  " and then calls it with the provided data
  return luaeval(s:lsp_module . '.handle(_A.filetype, _A.method, _A.data, _A.default_only)', {
        \ 'filetype': file_type,
        \ 'method': a:request,
        \ 'data': a:data,
        \ 'default_only': default_only,
        \ })
endfunction
