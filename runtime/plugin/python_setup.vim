" Nvim plugin for loading python extensions via an external interpreter
if exists("did_python_setup") || &cp
  finish
endif
let did_python_setup = 1


let s:get_version =
      \ ' -c "import sys; sys.stdout.write(str(sys.version_info[0]) + '.
      \ '\".\" + str(sys.version_info[1]))"'

let s:supported = ['2.6', '2.7']

" To load the python host a python 2 executable must be available
if exists('python_interpreter')
      \ && executable(g:python_interpreter)
      \ && index(s:supported, system(g:python_interpreter.s:get_version)) >= 0
  let s:python_interpreter = g:python_interpreter
elseif executable('python')
      \ && index(s:supported, system('python'.s:get_version)) >= 0
  let s:python_interpreter = 'python'
elseif executable('python2')
      \ && index(s:supported, system('python2'.s:get_version)) >= 0
  " In some distros, python3 is the default python
  let s:python_interpreter = 'python2'
else
  finish
endif

" Execute python, import neovim and print a string. If import_result matches
" the printed string, we can probably start the host
let s:import_result = system(s:python_interpreter .
      \ ' -c "import neovim, sys; sys.stdout.write(\"ok\")"')
if s:import_result != 'ok'
  finish
endif

let s:pyhost_id = rpcstart(s:python_interpreter,
      \ ['-c', 'import neovim; neovim.start_host()'])
" Evaluate an expression in the script host as an additional sanity check, and
" to block until all providers have been registered(or else some plugins loaded
" by the user's vimrc would not get has('python') == 1
if rpcrequest(s:pyhost_id, 'python_eval', '"o"+"k"') != 'ok' || !has('python')
  " Something went wrong
  rpcstop(s:pyhost_id)
endif
