" The Python3 provider uses a Python3 host to emulate an environment for running
" python3 plugins. :help provider
"
" Associating the plugin with the Python3 host is the first step because
" plugins will be passed as command-line arguments

if exists('g:loaded_python3_provider')
  finish
endif
let [s:prog, s:err] = provider#pythonx#Detect(3)
let g:loaded_python3_provider = empty(s:prog) ? 1 : 2

function! provider#python3#Prog() abort
  return s:prog
endfunction

function! provider#python3#Error() abort
  return s:err
endfunction

" The Python3 provider plugin will run in a separate instance of the Python3
" host.
call remote#host#RegisterClone('legacy-python3-provider', 'python3')
call remote#host#RegisterPlugin('legacy-python3-provider', 'script_host.py', [])

function! provider#python3#Call(method, args) abort
  if s:err != ''
    return
  endif
  if !exists('s:host')
    let s:rpcrequest = function('rpcrequest')

    " Ensure that we can load the Python3 host before bootstrapping
    try
      let s:host = remote#host#Require('legacy-python3-provider')
    catch
      let s:err = v:exception
      echohl WarningMsg
      echomsg v:exception
      echohl None
      return
    endtry
  endif
  return call(s:rpcrequest, insert(insert(a:args, 'python_'.a:method), s:host))
endfunction
