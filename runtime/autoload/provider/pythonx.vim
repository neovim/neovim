" The Python provider helper
if exists('s:loaded_pythonx_provider')
  finish
endif

let s:loaded_pythonx_provider = 1

function! provider#pythonx#Require(host) abort
  " Python host arguments
  let prog = provider#python3#Prog()
  let args = [prog, '-c', 'import sys; sys.path = [p for p in sys.path if p != ""]; import neovim; neovim.start_host()']


  " Collect registered Python plugins into args
  let python_plugins = remote#host#PluginsForHost(a:host.name)
  for plugin in python_plugins
    call add(args, plugin.path)
  endfor

  return provider#Poll(args, a:host.orig_name, '$NVIM_PYTHON_LOG_FILE', {'overlapped': v:true})
endfunction

function! s:get_python_executable_from_host_var(major_version) abort
  return expand(get(g:, 'python'.(a:major_version == 3 ? '3' : execute("throw 'unsupported'")).'_host_prog', ''), v:true)
endfunction

function! s:get_python_candidates(major_version) abort
  return {
        \ 3: ['python3', 'python3.12', 'python3.11', 'python3.10', 'python3.9', 'python3.8', 'python3.7', 'python']
        \ }[a:major_version]
endfunction

" Returns [path_to_python_executable, error_message]
function! provider#pythonx#Detect(major_version) abort
  return provider#pythonx#DetectByModule('neovim', a:major_version)
endfunction

" Returns [path_to_python_executable, error_message]
function! provider#pythonx#DetectByModule(module, major_version) abort
  let python_exe = s:get_python_executable_from_host_var(a:major_version)

  if !empty(python_exe)
    return [exepath(expand(python_exe, v:true)), '']
  endif

  let candidates = s:get_python_candidates(a:major_version)
  let errors = []

  for exe in candidates
    let [result, error] = provider#pythonx#CheckForModule(exe, a:module, a:major_version)
    if result
      return [exe, error]
    endif
    " Accumulate errors in case we don't find any suitable Python executable.
    call add(errors, error)
  endfor

  " No suitable Python executable found.
  return ['', 'Could not load Python '.a:major_version.":\n".join(errors, "\n")]
endfunction

" Returns array: [prog_exitcode, prog_version]
function! s:import_module(prog, module) abort
  let prog_version = system([a:prog, '-W', 'ignore', '-c', printf(
        \ 'import sys, importlib.util; ' .
        \ 'sys.path = [p for p in sys.path if p != ""]; ' .
        \ 'sys.stdout.write(str(sys.version_info[0]) + "." + str(sys.version_info[1])); ' .
        \ 'sys.exit(2 * int(importlib.util.find_spec("%s") is None))',
        \ a:module)])
  return [v:shell_error, prog_version]
endfunction

" Returns array: [was_success, error_message]
function! provider#pythonx#CheckForModule(prog, module, major_version) abort
  let prog_path = exepath(a:prog)
  if prog_path ==# ''
    return [0, a:prog . ' not found in search path or not executable.']
  endif

  let min_version = '3.7'

  " Try to load module, and output Python version.
  " Exit codes:
  "   0  module can be loaded.
  "   2  module cannot be loaded.
  "   Otherwise something else went wrong (e.g. 1 or 127).
  let [prog_exitcode, prog_version] = s:import_module(a:prog, a:module)

  if prog_exitcode == 2 || prog_exitcode == 0
    " Check version only for expected return codes.
    if prog_version !~ '^' . a:major_version
      return [0, prog_path . ' is Python ' . prog_version . ' and cannot provide Python '
            \ . a:major_version . '.']
    elseif prog_version =~ '^' . a:major_version && str2nr(prog_version[2:]) < str2nr(min_version[2:])
      return [0, prog_path . ' is Python ' . prog_version . ' and cannot provide Python >= '
            \ . min_version . '.']
    endif
  endif

  if prog_exitcode == 2
    return [0, prog_path.' does not have the "' . a:module . '" module.']
  elseif prog_exitcode == 127
    " This can happen with pyenv's shims.
    return [0, prog_path . ' does not exist: ' . prog_version]
  elseif prog_exitcode
    return [0, 'Checking ' . prog_path . ' caused an unknown error. '
          \ . '(' . prog_exitcode . ', output: ' . prog_version . ')'
          \ . ' Report this at https://github.com/neovim/neovim']
  endif

  return [1, '']
endfunction
