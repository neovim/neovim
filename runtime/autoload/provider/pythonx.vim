" The Python provider helper
if exists('s:loaded_pythonx_provider')
  finish
endif

let s:loaded_pythonx_provider = 1
let s:min_version = '3.7'

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

" Turn a path with a host-specific directory separator into Vim's
" comma-separated format.
function! s:to_comma_separated_path(path) abort
  if has('win32')
    let path_sep = ';'
    " remove backslashes at the end of path items, they would turn into \, and
    " escape the , which globpath() expects as path separator
    let path = substitute(a:path, '\\\+;', ';', 'g')
  else
    let path_sep = ':'
    let path = a:path
  endif

  " escape existing commas, so that they remain part of the individual paths
  let path = substitute(path, ',', '\\,', 'g')

  " deduplicate path items, otherwise globpath() returns even more duplicate
  " matches for some reason
  let already_seen = {}
  let path_list = []
  for item in split(path, path_sep)
    if !has_key(already_seen, item)
      let already_seen[item] = v:true
      call add(path_list, item)
    endif
  endfor

  return join(path_list, ',')
endfunction

" Returns a list of all Python executables found on path. a:convert specifies
" whether the path to search needs to be converted from a host-specific
" separator to the comma-separated format expected by globpath().
function! provider#pythonx#GetPythonCandidates(major_version, path, convert) abort
  let path = a:convert ? s:to_comma_separated_path(a:path) : a:path
  let starts_with_python = globpath(path, 'python*', v:true, v:true)
  let ext_pat = has('win32') ? '(\\.exe)?' : ''
  let matches_version = printf('v:val =~# "\\v[\\/]python(%d(\\.[0-9]+)?)?%s$"', a:major_version, ext_pat)
  return filter(starts_with_python, matches_version)
endfunction

" Returns [path_to_python_executable, python_version, error_messages]
function! provider#pythonx#Detect(major_version) abort
  return provider#pythonx#DetectByModule('neovim', a:major_version)
endfunction

" Returns [path_to_python_executable, python_version, error_messages]
function! provider#pythonx#DetectByModule(module, major_version) abort
  let host_prog = 'python'.(a:major_version == 3 ? '3' : '').'_host_prog'
  let python_exe = get(g:, host_prog, '')
  let errors = []

  if !empty(python_exe)
    let candidates = [exepath(expand(python_exe, v:true))]
    call add(errors, 'The g:'.host_prog.' you set cannot be used.')
  else
    let candidates = provider#pythonx#GetPythonCandidates(a:major_version, $PATH, v:true)
  endif

  if empty(candidates)
    call add(errors, 'No candidates for a Python '.a:major_version.' executable found on $PATH.')
  endif

  for exe in candidates
    let [result, python_version, error] = provider#pythonx#CheckForModule(exe, a:module, a:major_version)
    if result
      " If result, then discard any errors: for one thing, if one of the
      " candidates works, let's not add potentially confusing noise to health
      " reports. For another, some code might rely on the absence of errors as
      " a signal that everything went well (e.g. Nvim's own test suite does).
      return [exe, python_version, []]
    endif
    " Accumulate errors in case we don't find any suitable Python executable.
    call add(errors, error)
  endfor

  " No suitable Python executable found.
  return ['', '', errors]
endfunction

" Returns array: [prog_exitcode, prog_version]
function! s:import_module(prog, module) abort
  let prog_version = system([a:prog, '-c' , printf(
        \ 'import sys; ' .
        \ 'sys.path = [p for p in sys.path if p != ""]; ' .
        \ 'sys.stdout.write(".".join(str(x) for x in sys.version_info[:3])); ' .
        \ 'import pkgutil; ' .
        \ 'sys.exit(2*int(pkgutil.get_loader("%s") is None))',
        \ a:module)])
  return [v:shell_error, prog_version]
endfunction

function! s:satisfies_version(target, ref_major, ref_minimum) abort
  return a:target =~# '^' . a:ref_major . '\(\.\|$\)'
        \ && luaeval('vim.version_cmp(_A[1], _A[2]) >= 0', [a:target, a:ref_minimum])
endfunction

" Returns array: [was_success, python_version, error_message]
function! provider#pythonx#CheckForModule(prog_path, module, major_version) abort

  " Try to load module, and output Python version.
  " Exit codes:
  "   0  module can be loaded.
  "   2  module cannot be loaded.
  "   Otherwise something else went wrong (e.g. 1 or 127).
  let [prog_exitcode, prog_version] = s:import_module(a:prog_path, a:module)

  " Check version only for expected return codes.
  if (prog_exitcode == 2 || prog_exitcode == 0) && !s:satisfies_version(prog_version, a:major_version, s:min_version)
    return [0, '', a:prog_path . ' is Python ' . prog_version . ' and cannot provide Python '
          \ . a:major_version . ' >= ' . s:min_version . '.']
  endif

  if prog_exitcode == 2
    return [0, '', a:prog_path.' does not have the "' . a:module . '" module.']
  elseif prog_exitcode
    return [0, '', 'Checking ' . a:prog_path . ' exited with error code ' . prog_exitcode . '. '
          \ . 'If running the same executable from the command line works fine, report this at '
          \ . "https://github.com/neovim/neovim. This was the output:\n\n" . prog_version . "\n"]
  endif

  return [1, prog_version, '']
endfunction
