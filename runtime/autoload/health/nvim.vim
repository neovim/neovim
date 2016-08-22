let s:bad_responses = [
            \ 'unable to parse python response',
            \ 'unable to parse',
            \ 'unable to get pypi response',
            \ 'unable to get neovim executable',
            \ 'unable to find neovim version'
            \ ]

function! s:is_bad_response(s) abort
    return index(s:bad_responses, a:s) >= 0
endfunction

function! s:trim(s) abort
  return substitute(a:s, '^\_s*\|\_s*$', '', 'g')
endfunction

" Simple version comparison.
function! s:version_cmp(a, b) abort
  let a = split(a:a, '\.')
  let b = split(a:b, '\.')

  for i in range(len(a))
    if a[i] > b[i]
      return 1
    elseif a[i] < b[i]
      return -1
    endif
  endfor

  return 0
endfunction

" Fetch the contents of a URL.
function! s:download(url) abort
  let content = ''
  if executable('curl')
    let content = system(['curl', '-sL', "'", a:url, "'"])
  endif

  if empty(content) && executable('python')
    let script = "
          \try:\n
          \    from urllib.request import urlopen\n
          \except ImportError:\n
          \    from urllib2 import urlopen\n
          \\n
          \try:\n
          \    response = urlopen('".a:url."')\n
          \    print(response.read().decode('utf8'))\n
          \except Exception:\n
          \    pass\n
          \"
    let content = system(['python', '-c', "'", script, "'", '2>/dev/null'])
  endif

  return content
endfunction


" Get the latest Neovim Python client version from PyPI.  Result is cached.
function! s:latest_pypi_version() abort
  if exists('s:pypi_version')
    return s:pypi_version
  endif

  let s:pypi_version = 'unable to get pypi response'
  let pypi_info = s:download('https://pypi.python.org/pypi/neovim/json')
  if !empty(pypi_info)
    let pypi_data = json_decode(pypi_info)
    let s:pypi_version = get(get(pypi_data, 'info', {}), 'version', 'unable to parse')
    return s:pypi_version
  endif
endfunction

" Get version information using the specified interpreter.  The interpreter is
" used directly in case breaking changes were introduced since the last time
" Neovim's Python client was updated.
"
" Returns [
"           python executable version,
"           current nvim version,
"           current pypi nvim status,
"           installed version status
"         ]
function! s:version_info(python) abort
  let pypi_version = s:latest_pypi_version()
  let python_version = s:trim(system([
        \ a:python,
        \ '-c',
        \ 'import sys; print(".".join(str(x) for x in sys.version_info[:3]))',
        \ ]))

  if empty(python_version)
    let python_version = 'unable to parse python response'
  endif

  let nvim_path = s:trim(system([
        \ a:python,
        \ '-c',
        \ 'import neovim; print(neovim.__file__)',
        \ '2>/dev/null']))

  let nvim_path = s:trim(system([
        \ 'python3',
        \ '-c',
        \ 'import neovim; print(neovim.__file__)'
        \ ]))
        " \ '2>/dev/null']))

  if empty(nvim_path)
    return [python_version, 'unable to find neovim executable', pypi_version, 'unable to get neovim executable']
  endif

  let nvim_version = 'unable to find neovim version'
  let base = fnamemodify(nvim_path, ':h')		
  for meta in glob(base.'-*/METADATA', 1, 1) + glob(base.'-*/PKG-INFO', 1, 1)		
    for meta_line in readfile(meta)		
      if meta_line =~# '^Version:'		
        let nvim_version = matchstr(meta_line, '^Version: \zs\S\+')		
      endif		
    endfor		
  endfor

  let version_status = 'unknown'
  if !s:is_bad_response(nvim_version) && !s:is_bad_response(pypi_version)
    if s:version_cmp(nvim_version, pypi_version) == -1
      let version_status = 'outdated'
    else
      let version_status = 'up to date'
    endif
  endif

  return [python_version, nvim_version, pypi_version, version_status]
endfunction

" Check the Python interpreter's usability.
function! s:check_bin(bin) abort
  if !filereadable(a:bin)
    call health#report_error(printf('"%s" was not found.', a:bin))
    return 0
  elseif executable(a:bin) != 1
    call health#report_error(printf('"%s" is not executable.', a:bin))
    return 0
  endif
  return 1
endfunction

" Load the remote plugin manifest file and check for unregistered plugins
function! s:check_manifest() abort
  call health#report_start('Remote Plugins')
  let existing_rplugins = {}

  for item in remote#host#PluginsForHost('python')
    let existing_rplugins[item.path] = 'python'
  endfor

  for item in remote#host#PluginsForHost('python3')
    let existing_rplugins[item.path] = 'python3'
  endfor

  let require_update = 0

  for path in map(split(&runtimepath, ','), 'resolve(v:val)')
    let python_glob = glob(path.'/rplugin/python*', 1, 1)
    if empty(python_glob)
      continue
    endif

    let python_dir = python_glob[0]
    let python_version = fnamemodify(python_dir, ':t')

    for script in glob(python_dir.'/*.py', 1, 1)
          \ + glob(python_dir.'/*/__init__.py', 1, 1)
      let contents = join(readfile(script))
      if contents =~# '\<\%(from\|import\)\s\+neovim\>'
        if script =~# '/__init__\.py$'
          let script = fnamemodify(script, ':h')
        endif

        if !has_key(existing_rplugins, script)
          let msg = printf('"%s" is not registered.', fnamemodify(path, ':t'))
          if python_version ==# 'pythonx'
            if !has('python2') && !has('python3')
              let msg .= ' (python2 and python3 not available)'
            endif
          elseif !has(python_version)
            let msg .= printf(' (%s not available)', python_version)
          else
            let require_update = 1
          endif

          call health#report_warn(msg)
        endif

        break
      endif
    endfor
  endfor

  if require_update
    call health#report_warn('Out of date', ['Run `:UpdateRemotePlugins`'])
  else
    call health#report_ok('Up to date')
  endif
endfunction


function! s:check_python(version) abort
  call health#report_start('Python ' . a:version . ' provider')

  let python_bin_name = 'python'.(a:version == 2 ? '2' : '3')
  let pyenv = resolve(exepath('pyenv'))
  let pyenv_root = exists('$PYENV_ROOT') ? resolve($PYENV_ROOT) : 'n'
  let venv = exists('$VIRTUAL_ENV') ? resolve($VIRTUAL_ENV) : ''
  let host_prog_var = python_bin_name.'_host_prog'
  let host_skip_var = python_bin_name.'_host_skip_check'
  let python_bin = ''
  let python_multiple = []

  if exists('g:'.host_prog_var)
    call health#report_info(printf('Using: g:%s = "%s"', host_prog_var, get(g:, host_prog_var)))
  endif

  let [python_bin_name, pythonx_errs] = provider#pythonx#Detect(a:version)
  if empty(python_bin_name)
    call health#report_warn('No Python interpreter was found with the neovim '
            \ . 'module.  Using the first available for diagnostics.')
    if !empty(pythonx_errs)
      call health#report_warn(pythonx_errs)
    endif
    let old_skip = get(g:, host_skip_var, 0)
    let g:[host_skip_var] = 1
    let [python_bin_name, pythonx_errs] = provider#pythonx#Detect(a:version)
    let g:[host_skip_var] = old_skip
  endif

  if !empty(python_bin_name)
    if exists('g:'.host_prog_var)
      let python_bin = exepath(python_bin_name)
    endif
    let python_bin_name = fnamemodify(python_bin_name, ':t')
  endif

  if !empty(pythonx_errs)
    call health#report_error('Python provider error', pythonx_errs)
  endif

  if !empty(python_bin_name) && empty(python_bin) && empty(pythonx_errs)
    if !exists('g:'.host_prog_var)
      call health#report_info(printf('`g:%s` is not set.  Searching for '
            \ . '%s in the environment.', host_prog_var, python_bin_name))
    endif

    if !empty(pyenv)
      if empty(pyenv_root)
        call health#report_warn(
              \ 'pyenv was found, but $PYENV_ROOT is not set.',
              \ ['Did you follow the final install instructions?']
              \ )
      else
        call health#report_ok(printf('pyenv found: "%s"', pyenv))
      endif

      let python_bin = s:trim(system(
            \ printf('"%s" which %s 2>/dev/null', pyenv, python_bin_name)))

      if empty(python_bin)
        call health#report_warn(printf('pyenv couldn''t find %s.', python_bin_name))
      endif
    endif

    if empty(python_bin)
      let python_bin = exepath(python_bin_name)

      if exists('$PATH')
        for path in split($PATH, ':')
          let path_bin = path.'/'.python_bin_name
          if path_bin != python_bin && index(python_multiple, path_bin) == -1
                \ && executable(path_bin)
            call add(python_multiple, path_bin)
          endif
        endfor

        if len(python_multiple)
          " This is worth noting since the user may install something
          " that changes $PATH, like homebrew.
          call health#report_info(printf('There are multiple %s executables found.  '
                \ . 'Set "g:%s" to avoid surprises.', python_bin_name, host_prog_var))
        endif

        if python_bin =~# '\<shims\>'
          call health#report_warn(printf('"%s" appears to be a pyenv shim.', python_bin), [
                      \ 'The "pyenv" executable is not in $PATH,',
                      \ 'Your pyenv installation is broken. You should set '
                      \ . '"g:'.host_prog_var.'" to avoid surprises.',
                      \ ])
        endif
      endif
    endif
  endif

  if !empty(python_bin)
    if empty(venv) && !empty(pyenv) && !exists('g:'.host_prog_var)
          \ && !empty(pyenv_root) && resolve(python_bin) !~# '^'.pyenv_root.'/'
      call health#report_warn('pyenv is not set up optimally.', [
            \ printf('Suggestion: Create a virtualenv specifically '
            \ . 'for Neovim using pyenv and use "g:%s".  This will avoid '
            \ . 'the need to install Neovim''s Python client in each '
            \ . 'version/virtualenv.', host_prog_var)
            \ ])
    elseif !empty(venv) && exists('g:'.host_prog_var)
      if !empty(pyenv_root)
        let venv_root = pyenv_root
      else
        let venv_root = fnamemodify(venv, ':h')
      endif

      if resolve(python_bin) !~# '^'.venv_root.'/'
        call health#report_warn('Your virtualenv is not set up optimally.', [
              \ printf('Suggestion: Create a virtualenv specifically '
              \ . 'for Neovim and use "g:%s".  This will avoid '
              \ . 'the need to install Neovim''s Python client in each '
              \ . 'virtualenv.', host_prog_var)
              \ ])
      endif
    endif
  endif

  if empty(python_bin) && !empty(python_bin_name)
    " An error message should have already printed.
    call health#report_error(printf('"%s" was not found.', python_bin_name))
  elseif !empty(python_bin) && !s:check_bin(python_bin)
    let python_bin = ''
  endif

  " Check if $VIRTUAL_ENV is active
  let virtualenv_inactive = 0

  if exists('$VIRTUAL_ENV')
    if !empty(pyenv)
      let pyenv_prefix = resolve(s:trim(system([pyenv, 'prefix'])))
      if $VIRTUAL_ENV != pyenv_prefix
        let virtualenv_inactive = 1
      endif
    elseif !empty(python_bin_name) && exepath(python_bin_name) !~# '^'.$VIRTUAL_ENV.'/'
      let virtualenv_inactive = 1
    endif
  endif

  if virtualenv_inactive
    let suggestions = [
          \ 'If you are using Zsh, see: http://vi.stackexchange.com/a/7654/5229',
          \ ]
    call health#report_warn(
          \ '$VIRTUAL_ENV exists but appears to be inactive. '
          \ . 'This could lead to unexpected results.',
          \ suggestions)
  endif

  " Diagnostic output
  call health#report_info('Executable: ' . (empty(python_bin) ? 'Not found' : python_bin))
  if len(python_multiple)
    for path_bin in python_multiple
      call health#report_info('Other python executable: ' . path_bin)
    endfor
  endif

  if !empty(python_bin)
    let [pyversion, current, latest, status] = s:version_info(python_bin)
    if a:version != str2nr(pyversion)
      call health#report_warn('Got an unexpected version of Python.' .
                  \ ' This could lead to confusing error messages.')
    endif
    if a:version == 3 && str2float(pyversion) < 3.3
      call health#report_warn('Python 3.3+ is recommended.')
    endif

    call health#report_info('Python'.a:version.' version: ' . pyversion)
    call health#report_info(printf('%s-neovim Version: %s', python_bin_name, current))

    if s:is_bad_response(current)
      let suggestions = [
            \ 'Error found was: ' . current,
            \ 'Use the command `$ pip' . a:version . ' install neovim`',
            \ ]
      call health#report_error(
            \ 'Neovim Python client is not installed.',
            \ suggestions)
    endif

    if s:is_bad_response(latest)
      call health#report_warn('Unable to fetch latest Neovim Python client version.')
    endif

    if s:is_bad_response(status)
      call health#report_warn('Latest Neovim Python client versions: ('.latest.')')
    else
      call health#report_ok('Latest Neovim Python client is installed: ('.status.')')
    endif
  endif

endfunction

function! s:check_ruby() abort
  call health#report_start('Ruby provider')
  let min_version  = "0.2.4"
  let ruby_version = systemlist('ruby -v')[0]
  let ruby_prog    = provider#ruby#Detect()
  let suggestions  =
        \ ['Install or upgrade the neovim RubyGem using `gem install neovim`.']

  if empty(ruby_prog)
    let ruby_prog = 'not found'
    let prog_vers = 'not found'
    call health#report_error('Missing Neovim RubyGem', suggestions)
  else
    silent let prog_vers = systemlist(ruby_prog . ' --version')[0]
    if v:shell_error
      let prog_vers = 'outdated'
      call health#report_warn('Neovim RubyGem is not up-to-date', suggestions)
    elseif s:version_cmp(prog_vers, min_version) == -1
      let prog_vers .= ' (outdated)'
      call health#report_warn('Neovim RubyGem is not up-to-date', suggestions)
    else
      call health#report_ok('Found Neovim RubyGem')
    endif
  endif

  call health#report_info('Ruby Version: ' . ruby_version)
  call health#report_info('Host Executable: ' . ruby_prog)
  call health#report_info('Host Version: ' . prog_vers)
endfunction

function! health#nvim#check() abort
  call s:check_manifest()
  call s:check_python(2)
  call s:check_python(3)
  call s:check_ruby()
endfunction
