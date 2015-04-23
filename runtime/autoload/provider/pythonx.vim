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
    " Disable auto detection
    let [check, err] = s:check_interpreter({host_var}, a:ver, skip)
    return check ? [{host_var}, err] : ['', err]
  endif

  let detect_versions = (a:ver == 2) ?
        \   ['2.7', '2.6', '2', '']
        \ : ['3.5', '3.4', '3.3', '3.2', '3', '']

  for prog in map(detect_versions, "'python' . v:val")
    let [check, err] = s:check_interpreter(prog, a:ver, skip)
    if check
      let [check, err] = s:check_version(prog, a:ver, skip)
      return [prog, err]
    endif
  endfor

  " No Python interpreter
  return ['', 'Neovim module installed Python'
        \ .a:ver.' interpreter is not found.']
endfunction

function! s:check_version(prog, ver, skip) abort
  if a:skip
    return [1, '']
  endif

  let get_version =
        \ ' -c "import sys; sys.stdout.write(str(sys.version_info[0]) + '.
        \ '\".\" + str(sys.version_info[1]))"'
  let min_version = (a:ver == 2) ? '2.6' : '3.3'
  if system(a:prog . get_version) >= min_version
    return [1, '']
  endif
  return [0, 'Python ' . get_version . ' interpreter is not supported.']
endfunction

function! s:check_interpreter(prog, ver, skip) abort
  if !executable(a:prog)
    return [0, 'Python'.a:ver.' interpreter is not executable.']
  endif

  if a:skip
    return [1, '']
  endif

  " Load neovim module check
  call system(a:prog . ' -c ' .
        \ (a:ver == 2 ?
        \   '''import pkgutil; exit(pkgutil.get_loader("neovim") is None)''':
        \   '''import importlib; exit(importlib.find_loader("neovim") is None)''')
        \ )
  return [!v:shell_error, 'Python'.a:ver.' interpreter have not neovim module.']
endfunction

