" TODO:
"   Simplify "request", "request_async", and "notify"

try
  " Try and load the LSP API.
  lua require('lsp.api')
catch
  echom 'Language Server Protocol is currently not able to run.'
  finish
endtry

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


""
" Private functions to manage language server.
"   Easier to configure on the viml side, since you can pass callbacks to the
"   API, which -- at the time -- isn't possible with lua {{{
let s:LspClient = {}

function s:LspClient.on_stdout(job_id, data, event) abort
  call luaeval("require('lsp.client').job_stdout(_A.id, _A.data)", {'id': a:job_id, 'data': a:data})
endfunction

function s:LspClient.on_exit(job_id, data, event) abort
  call luaeval("require('lsp.client').job_exit(_A.id, _A.data)", {'id': a:job_id, 'data': a:data})
endfunction

function lsp#__jobstart(cmd) abort
  let to_execute = ''
  if type(a:cmd) == v:t_string
    let to_execute = split(a:cmd, ' ', 0)[0]
  elseif type(a:cmd) == v:t_list && len(a:cmd) > 0
    let to_execute = a:cmd[0]
  else
    echoerr 'Invalid command arguments for LSP'
    throw LSP/BadConfig
  endif

  if !executable(to_execute)
    echoerr '"' to_execute '" is not a valid executable'
    throw LSP/BadConfig
  endif


  let job_id = jobstart(a:cmd, s:LspClient)

  if job_id == 0
    echoerr 'Invalid arguments for LSP'
    throw LSP/failed
  elseif job_id == -1
    echoerr 'Not a valid executable: ' . string(a:cmd)
    throw LSP/failed
  endif

  return job_id
endfunction
" }}}
