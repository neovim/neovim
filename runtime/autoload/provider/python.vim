" The Python provider uses a Python host to emulate an environment for running
" python-vim plugins. See ":help nvim-provider" for more information.
"
" Associating the plugin with the Python host is the first step because plugins
" will be passed as command-line arguments

if exists('g:loaded_python_provider')
  finish
endif
let g:loaded_python_provider = 1

let [s:prog, s:err] = provider#pythonx#Detect(2)

function! provider#python#Prog()
  return s:prog
endfunction

function! provider#python#Error()
  return s:err
endfunction

if s:prog == ''
  " Detection failed
  finish
endif

let s:plugin_path = expand('<sfile>:p:h').'/script_host.py'

" The Python provider plugin will run in a separate instance of the Python
" host.
call remote#host#RegisterClone('legacy-python-provider', 'python')
call remote#host#RegisterPlugin('legacy-python-provider', s:plugin_path, [])

function! provider#python#Call(method, args)
  if s:err != ''
    return
  endif
  if !exists('s:host')
    let s:rpcrequest = function('rpcrequest')

    " Ensure that we can load the Python host before bootstrapping
    try
      let s:host = remote#host#Require('legacy-python-provider')
    catch
      let s:err = v:exception
      echohl WarningMsg
      echomsg v:exception
      echohl None
      finish
    endtry
  endif
  return call(s:rpcrequest, insert(insert(a:args, 'python_'.a:method), s:host))
endfunction
