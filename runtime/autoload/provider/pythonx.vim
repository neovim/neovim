" The Python provider helper
if exists('s:loaded_pythonx_provider')
  finish
endif

let s:loaded_pythonx_provider = 1

let s:stderr = {}
let s:job_opts = {'rpc': v:true}

" TODO(bfredl): this logic is common and should be builtin
function! s:job_opts.on_stderr(chan_id, data, event) dict
  let stderr = get(s:stderr, a:chan_id, [''])
  let last = remove(stderr, -1)
  let a:data[0] = last.a:data[0]
  call extend(stderr, a:data)
  let s:stderr[a:chan_id] = stderr
endfunction

function! s:job_opts.on_exit(chan_id, code, event) dict abort
  " UpdateRemotePlugin have it's own handler
  if a:code == 0 | return | endif
  echoerr self.orig_name.' provider exited with code '.a:code
  for row in get(s:stderr, a:chan_id, [])
    echoerr row
  endfor
  unlet s:stderr[a:chan_id]
  "throw remote#host#LoadErrorForHost(self.orig_name,
  "      \ '$NVIM_PYTHON_LOG_FILE')
endfunction

function! provider#pythonx#Require(host) abort
  let ver = (a:host.orig_name ==# 'python') ? 2 : 3

  " Python host arguments
  let prog = (ver ==# '2' ?  provider#python#Prog() : provider#python3#Prog())
  let args = [prog, '-c', 'import sys; sys.path.remove(""); import neovim; neovim.start_host()']

  " Collect registered Python plugins into args
  let python_plugins = remote#host#PluginsForHost(a:host.name)
  for plugin in python_plugins
    call add(args, plugin.path)
  endfor

  let opts = deepcopy(s:job_opts)
  let opts.orig_name = a:host.orig_name
  let channel_id = jobstart(args, opts)

  if channel_id == -1
    echoerr prog . ' is not executable. Try :CheckHealth'
  endif

  return channel_id
endfunction

function! provider#pythonx#Detect(major_ver) abort
  if a:major_ver == 2
    if exists('g:python_host_prog')
      return [g:python_host_prog, '']
    else
      let progs = ['python2', 'python2.7', 'python2.6', 'python']
    endif
  else
    if exists('g:python3_host_prog')
      return [g:python3_host_prog, '']
    else
      let progs = ['python3', 'python3.7', 'python3.6', 'python3.5',
            \ 'python3.4', 'python3.3', 'python']
    endif
  endif

  let errors = []

  for prog in progs
    let [result, err] = s:check_interpreter(prog, a:major_ver)
    if result
      return [prog, err]
    endif
    " Accumulate errors in case we don't find
    " any suitable Python interpreter.
    call add(errors, err)
  endfor

  " No suitable Python interpreter found.
  return ['', 'provider/pythonx: Could not load Python ' . a:major_ver
        \ . ":\n" .  join(errors, "\n")]
endfunction

function! s:check_interpreter(prog, major_ver) abort
  let prog_path = exepath(a:prog)
  if prog_path ==# ''
    return [0, a:prog . ' not found in search path or not executable.']
  endif

  let min_version = (a:major_ver == 2) ? '2.6' : '3.3'

  " Try to load neovim module, and output Python version.
  " Return codes:
  "   0  Neovim module can be loaded.
  "   2  Neovim module cannot be loaded.
  "   Otherwise something else went wrong (e.g. 1 or 127).
  let prog_ver = system([ a:prog , '-c' ,
        \ 'import sys; ' .
        \ 'sys.path.remove(""); ' .
        \ 'sys.stdout.write(str(sys.version_info[0]) + "." + str(sys.version_info[1])); ' .
        \ 'import pkgutil; ' .
        \ 'exit(2*int(pkgutil.get_loader("neovim") is None))'
        \ ])

  if v:shell_error == 2 || v:shell_error == 0
    " Check version only for expected return codes.
    if prog_ver !~ '^' . a:major_ver
      return [0, prog_path . ' is Python ' . prog_ver . ' and cannot provide Python '
            \ . a:major_ver . '.']
    elseif prog_ver =~ '^' . a:major_ver && prog_ver < min_version
      return [0, prog_path . ' is Python ' . prog_ver . ' and cannot provide Python >= '
            \ . min_version . '.']
    endif
  endif

  if v:shell_error == 2
    return [0, prog_path.' does not have the "neovim" module. :help provider-python']
  elseif v:shell_error == 127
    " This can happen with pyenv's shims.
    return [0, prog_path . ' does not exist: ' . prog_ver]
  elseif v:shell_error
    return [0, 'Checking ' . prog_path . ' caused an unknown error. '
          \ . '(' . v:shell_error . ', output: ' . prog_ver . ')'
          \ . ' Report this at https://github.com/neovim/neovim']
  endif

  return [1, '']
endfunction
