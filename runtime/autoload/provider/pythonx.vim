" The Python provider helper
if exists('s:loaded_pythonx_provider')
  finish
endif

let s:loaded_pythonx_provider = 1

let s:stderr = {}
let s:job_opts = {'rpc': v:true}

" TODO(bfredl): this logic is common and should be builtin
function! s:job_opts.on_stderr(chan_id, data, event)
  let stderr = get(s:stderr, a:chan_id, [''])
  let last = remove(stderr, -1)
  let a:data[0] = last.a:data[0]
  call extend(stderr, a:data)
  let s:stderr[a:chan_id] = stderr
endfunction

function! provider#pythonx#Require(host) abort
  let ver = (a:host.orig_name ==# 'python') ? 2 : 3

  " Python host arguments
  let prog = (ver == '2' ?  provider#python#Prog() : provider#python3#Prog())
  let args = [prog, '-c', 'import sys; sys.path.remove(""); import neovim; neovim.start_host()']

  " Collect registered Python plugins into args
  let python_plugins = remote#host#PluginsForHost(a:host.name)
  for plugin in python_plugins
    call add(args, plugin.path)
  endfor

  try
    let channel_id = jobstart(args, s:job_opts)
    if rpcrequest(channel_id, 'poll') ==# 'ok'
      return channel_id
    endif
  catch
    echomsg v:throwpoint
    echomsg v:exception
    for row in get(s:stderr, channel_id, [])
      echomsg row
    endfor
  endtry
  throw remote#host#LoadErrorForHost(a:host.orig_name,
        \ '$NVIM_PYTHON_LOG_FILE')
endfunction

function! provider#pythonx#Detect(major_ver) abort
  let host_var = (a:major_ver == 2) ?
        \ 'g:python_host_prog' : 'g:python3_host_prog'
  let skip_var = (a:major_ver == 2) ?
        \ 'g:python_host_skip_check' : 'g:python3_host_skip_check'
  let skip = exists(skip_var) ? {skip_var} : 0
  if exists(host_var)
    " Disable auto detection.
    let [result, err] = s:check_interpreter({host_var}, a:major_ver, skip)
    if result
      return [{host_var}, err]
    endif
    return ['', 'provider/pythonx: Could not load Python ' . a:major_ver
          \ . ' from ' . host_var . ': ' . err]
  endif

  let prog_suffixes = (a:major_ver == 2) ?
        \   ['2', '2.7', '2.6', '']
        \ : ['3', '3.5', '3.4', '3.3', '']

  let errors = []
  for prog in map(prog_suffixes, "'python' . v:val")
    let [result, err] = s:check_interpreter(prog, a:major_ver, skip)
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

function! s:check_interpreter(prog, major_ver, skip) abort
  let prog_path = exepath(a:prog)
  if prog_path ==# ''
    return [0, a:prog . ' not found in search path or not executable.']
  endif

  if a:skip
    return [1, '']
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
    return [0, prog_path . ' does not have the neovim module installed. '
          \ . 'See ":help provider-python".']
  elseif v:shell_error == 127
    " This can happen with pyenv's shims.
    return [0, prog_path . ' does not exist: ' . prog_ver]
  elseif v:shell_error
    return [0, 'Checking ' . prog_path . ' caused an unknown error. '
          \ . '(' . v:shell_error . ', output: ' . prog_ver . ')'
          \ . ' Please report this at github.com/neovim/neovim.']
  endif

  return [1, '']
endfunction
