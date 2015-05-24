" The Python provider helper
if exists('s:loaded_pythonx_provider')
  finish
endif

let s:loaded_pythonx_provider = 1

function! provider#pythonx#Detect(major_ver) abort
  let host_var = (a:major_ver == 2) ?
        \ 'g:python_host_prog' : 'g:python3_host_prog'
  let skip_var = (a:major_ver == 2) ?
        \ 'g:python_host_skip_check' : 'g:python3_host_skip_check'
  let skip = exists(skip_var) ? {skip_var} : 0
  if exists(host_var)
    " Disable auto detection.
    let [result, err, _] = s:check_interpreter({host_var}, a:major_ver, skip)
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
    let [result, err, prog_ver] = s:check_interpreter(prog, a:major_ver, skip)
    if result
      let [result, err] = s:check_version(prog, prog_ver, a:major_ver, skip)
      if result
        return [prog, err]
      endif
    endif

    " Accumulate errors in case we don't find
    " any suitable Python interpreter.
    call add(errors, err)
  endfor

  " No suitable Python interpreter found.
  return ['', 'provider/pythonx: Could not load Python ' . a:major_ver
        \ . ":\n" .  join(errors, "\n")]
endfunction

function! s:check_version(prog, prog_ver, major_ver, skip) abort
  if a:skip
    return [1, '']
  endif

  let min_version = (a:major_ver == 2) ? '2.6' : '3.3'
  if a:prog_ver =~ '^' . a:major_ver && a:prog_ver >= min_version
    return [1, '']
  endif
  return [0, a:prog . ' is Python ' . prog_ver . ' and cannot provide Python '
        \ . a:major_ver . '.']
endfunction

function! s:check_interpreter(prog, major_ver, skip) abort
  if !executable(a:prog)
    return [0, a:prog . ' does not exist or is not executable.', '']
  endif

  if a:skip
    return [1, '', '']
  endif

  " Try to load neovim module, and output Python version.
  let prog_ver = system(a:prog . ' -c ' .
        \ '''import sys; sys.stdout.write(str(sys.version_info[0]) + '.
        \ '"." + str(sys.version_info[1])); '''.
        \ (a:major_ver == 2 ?
        \   '''import pkgutil; exit(pkgutil.get_loader("neovim") is None)''':
        \   '''import importlib; exit(importlib.find_loader("neovim") is None)''')
        \ )
  if v:shell_error
    return [0, a:prog  . ' does have not have the neovim module installed. '
          \ . 'See ":help nvim-python".', prog_ver]
  endif
  return [1, '', prog_ver]
endfunction

