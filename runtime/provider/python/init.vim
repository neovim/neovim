" The python provider uses a python host to emulate an environment for running
" python-vim plugins(:h python-vim). See :h nvim-providers for more
" information.
if type(rpc#host#Status('python')) != type(0)
  finish
endif

let s:host = 0
let s:plugin_path = expand('<sfile>:p:h').'/script_host.py'
let s:rpcrequest = function('rpcrequest')

function! s:Bootstrap()
  " Ensure the host is running and get it's id
  let s:host = rpc#host#Require('python')
  " Load the plugin into the host
  call rpcrequest(s:host, 'plugin_load', s:plugin_path)
  " Remove the s:Bootstrap() call from the ProviderCall autocmmand
  augroup python_provider_init
    au!
  augroup end
endfunction

augroup python_provider_init
  au ProviderCall python_* call s:Bootstrap()
augroup end

au ProviderCall python_* let v:provider_result =
      \ call(s:rpcrequest,
      \      insert(insert(v:provider_args, expand('<amatch>')), s:host))
