
let s:LspClient = {}

function s:LspClient.on_stdout(job_id, data, event) abort
  call luaeval("require('runtime.lua.lsp.client').job_stdout(_A.id, _A.data)", {'id': a:job_id, 'data': a:data})
endfunction

function s:LspClient.on_exit(job_id, data, event) abort
  if a:data == 0
    return
  end

  echom printf('[LSP] Exiting job id: %s -- %s: %s', a:job_id, a:event, a:data)
endfunction

""
" 
function! lsp#job#start(cmd, args) abort
  let cmd_list = [a:cmd]
  call extend(cmd_list, a:args)

  let job_id = jobstart(cmd_list, s:LspClient)

  if job_id == 0
    echoerr 'Invalid arguments for LSP'
    throw LSP/failed
  elseif job_id == -1
    echoerr 'Not a valid executable: ' . a:cmd
    throw LSP/failed
  endif

  return job_id
endfunction
