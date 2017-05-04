
let s:LspClient = {}

function s:LspClient.on_stdout(job_id, data, event) abort
  call luaeval("require('runtime.lua.lsp.client').job_stdout(_A.id, _A.data)", {'id': a:job_id, 'data': a:data})
endfunction

""
" 
function! lsp#job#start(cmd, ...) abort
  let cmd_list = [a:cmd]
  call extend(cmd_list, get(a:000, 1, []))

  let job_id = jobstart(cmd_list, s:LspClient)

  return job_id
endfunction
