let s:hosts = {}


" Register a host by associating it with a factory(funcref)
function! rpc#host#Register(name, factory)
  let s:hosts[a:name] = {
        \ 'factory': a:factory,
        \ 'command': '',
        \ 'argv': [],
        \ 'channel': 0,
        \ 'initialized': 0
        \ }
  if type(a:factory) == type(1) && a:factory
    " Passed a channel directly
    let s:hosts[a:name].channel = a:factory
  endif
endfunction


" Get the availability status of a host. This will return 1 if the host has
" already been initialized or if a bootstrap command is available. In all other
" cases, this returns an error message.
function! rpc#host#Status(name)
  if !has_key(s:hosts, a:name)
    return 'No host named "'.a:name.'" is registered'
  endif
  let host = s:hosts[a:name]
  if host.channel || host['command'] != ''
    return 1
  endif
  let result = call(host.factory, [a:name])
  if type(result) == type('')
    return result
  endif
  if type(result) == type([])
    let host['command'] = result[0]
    let host.argv = result[1]
  endif
  return host['command'] != '' || host.channel
endfunction


" Get a host channel, bootstrapping it if necessary
function! rpc#host#Require(name)
  let error = rpc#host#Status(a:name)
  if type(error) == type('')
    " Error string
    throw error
  endif
  let host = s:hosts[a:name]
  if !host.channel && !host.initialized
    if host['command'] != ''
      let host.channel = rpcstart(host['command'], host.argv)
    endif
    let host.initialized = 1
  endif
  return host.channel
endfunction


" Registration of standard hosts

" Python {{{
function! s:DetectPythonHost(name)
  let get_version =
        \ ' -c "import sys; sys.stdout.write(str(sys.version_info[0]) + '.
        \ '\".\" + str(sys.version_info[1]))"'

  let supported = ['2.6', '2.7']

  " To load the python host a python executable must be available
  if exists('python_interpreter')
        \ && executable(g:python_interpreter)
        \ && index(supported, system(g:python_interpreter.get_version)) >= 0
    let python_interpreter = g:python_interpreter
  elseif executable('python')
        \ && index(supported, system('python'.get_version)) >= 0
    let python_interpreter = 'python'
  elseif executable('python2')
        \ && index(supported, system('python2'.get_version)) >= 0
    " In some distros, python3 is the default python
    let python_interpreter = 'python2'
  else
    return 'No python interpreter found'
  endif

  " Make sure we pick correct python version on path.
  let python_interpreter = exepath(python_interpreter)
  let python_version = systemlist(python_interpreter . ' --version')[0]

  " Execute python, import neovim and print a string. If import_result matches
  " the printed string, we can probably start the host
  let import_result = system(python_interpreter .
        \ ' -c "import neovim, sys; sys.stdout.write(\"ok\")"')
  if import_result != 'ok'
    return 'No neovim module found for ' . python_version
  endif

  return [python_interpreter, ['-c', 'import neovim; neovim.start_host()']]
endfunction

call rpc#host#Register('python', function('s:DetectPythonHost'))
" }}}
