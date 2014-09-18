" Nvim plugin for loading python extensions via an external interpreter
if exists("did_python_setup") || &cp
  finish
endif
let did_python_setup = 1

if exists('python_interpreter')
      \ && executable(g:python_interpreter)
    let s:python_interpreter = g:python_interpreter  
elseif executable('python2')
    " In some distros, python points to python3, so we prefer python2 if available
    let s:python_interpreter = 'python2'
elseif executable('python')
    let s:python_interpreter = 'python'
else
  echoerr expand('<sfile>').": no python interpreter available."
  finish
endif

let s:python_version = matchstr(system(s:python_interpreter." --version"), '\d*\.\d*')
if s:python_version !~ '^2\.[67]'
    echoerr expand('<sfile>').": python ".s:python_version." not supported."
    finish
endif
    
let s:pyhost_id = rpcstart(s:python_interpreter,
      \ ['-c', 'import neovim; neovim.start_host()'])
if s:pyhost_id == 0
  echoerr expand('<sfile>').": python host failed to start." 
else
  " Evaluate an expression in the script host as an additional sanity check, and
  " to block until all providers have been registered(or else some plugins loaded
  " by the user's vimrc would not get has('python') == 1
  if rpcrequest(s:pyhost_id, 'python_eval', '"o"+"k"') != 'ok' || !has('python')
    rpcstop(s:pyhost_id)
    echoerr expand('<sfile>').": python host had to be stopped."
  endif
endif
