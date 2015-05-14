" The Python provider helper
if exists('s:loaded_pythonx_provider')
  finish
endif

let s:loaded_pythonx_provider = 1

function! provider#pythonx#Detect(ver) abort
  let host_var = (a:ver == 2) ?
        \ 'g:python_host_prog' : 'g:python3_host_prog'
  let skip_var = (a:ver == 2) ?
        \ 'g:python_host_skip_check' : 'g:python3_host_skip_check'
  let skip = exists(skip_var) ? {skip_var} : 0
  if exists(host_var)
    " Disable auto detection.
    let [check, err, _] = s:check_interpreter({host_var}, a:ver, skip)
    if check
      return [{host_var}, err]
    endif
    return ['', 'provider#pythonx#Detect: could not load Python '.a:ver
          \ .' (from '.host_var.'): '.err]
  endif

  let detect_versions = (a:ver == 2) ?
        \   ['2', '2.7', '2.6', '']
        \ : ['3', '3.5', '3.4', '3.3', '']

  for prog in map(detect_versions, "'python' . v:val")
    let [check, err, ver] = s:check_interpreter(prog, a:ver, skip)
    if check
      let [check, err] = s:check_version(prog, ver, skip)
      if check
        return [prog, err]
      endif
    endif
  endfor

  return ['', 'provider#pythonx#Detect: could not load Python '.a:ver
        \ .': '.err]
endfunction

function! s:check_version(prog, ver, skip) abort
  if a:skip
    return [1, '']
  endif

  let min_version = (a:ver[0] == 2) ? '2.6' : '3.3'
  if a:ver >= min_version
    return [1, '']
  endif
  return [0, 'Python ' . a:ver . ' interpreter is not supported.']
endfunction

function! s:check_interpreter(prog, ver, skip) abort
  if !executable(a:prog)
    return [0, 'Python'.a:ver.' interpreter is not executable.', '']
  endif

  if a:skip
    return [1, '', '']
  endif

  " Try to load neovim module, and output Python version.
  let ver = system(a:prog . ' -c ' .
        \ '''import sys; sys.stdout.write(str(sys.version_info[0]) + '.
        \ '"." + str(sys.version_info[1])); '''.
        \ (a:ver == 2 ?
        \   '''import pkgutil; exit(pkgutil.get_loader("neovim") is None)''':
        \   '''import importlib; exit(importlib.find_loader("neovim") is None)''')
        \ )
  if v:shell_error
    return [0, 'Python'.a:ver.' interpreter ('.a:prog.') has no neovim module installed. See ":help nvim-python".', ver]
  endif
  return [1, '', ver]
endfunction

