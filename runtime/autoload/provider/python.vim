" The python provider uses a python host to emulate an environment for running
" python-vim plugins(:h python-vim). See :h nvim-providers for more
" information.
"
" Associating the plugin with the python host is the first step because plugins
" will be passed as command-line arguments
if exists('s:loaded_python_provider') || &cp
  finish
endif
let s:loaded_python_provider = 1
let s:plugin_path = expand('<sfile>:p:h').'/script_host.py'
" The python provider plugin will run in a separate instance of the python
" host.
call remote#host#RegisterClone('legacy-python-provider', 'python')
call remote#host#RegisterPlugin('legacy-python-provider', s:plugin_path, [])
" Ensure that we can load the python host before bootstrapping
try
  let s:host = remote#host#Require('legacy-python-provider')
catch
  echomsg v:exception
  finish
endtry

let s:rpcrequest = function('rpcrequest')

function! provider#python#Call(method, args)
  return call(s:rpcrequest, insert(insert(a:args, 'python_'.a:method), s:host))
endfunction
