let s:shell_error = 0

function! s:is_bad_response(s) abort
  return a:s =~? '\v(^unable)|(^error)|(^outdated)'
endfunction

function! s:trim(s) abort
  return substitute(a:s, '^\_s*\|\_s*$', '', 'g')
endfunction

" Simple version comparison.
function! s:version_cmp(a, b) abort
  let a = split(a:a, '\.', 0)
  let b = split(a:b, '\.', 0)

  for i in range(len(a))
    if str2nr(a[i]) > str2nr(b[i])
      return 1
    elseif str2nr(a[i]) < str2nr(b[i])
      return -1
    endif
  endfor

  return 0
endfunction

" Handler for s:system() function.
function! s:system_handler(jobid, data, event) abort
  if a:event == 'stdout' || a:event == 'stderr'
    let self.output .= join(a:data, '')
  elseif a:event == 'exit'
    let s:shell_error = a:data
  endif
endfunction

" Run a system command and timeout after 30 seconds.
function! s:system(cmd, ...) abort
  let stdin = a:0 ? a:1 : ''
  let opts = {
        \ 'output': '',
        \ 'on_stdout': function('s:system_handler'),
        \ 'on_stderr': function('s:system_handler'),
        \ 'on_exit': function('s:system_handler'),
        \ }
  let jobid = jobstart(a:cmd, opts)

  if jobid < 1
    call health#report_error(printf('Command error %d: %s', jobid,
          \ type(a:cmd) == type([]) ? join(a:cmd) : a:cmd)))
    let s:shell_error = 1
    return opts.output
  endif

  if !empty(stdin)
    call jobsend(jobid, stdin)
  endif

  let res = jobwait([jobid], 30000)
  if res[0] == -1
    call health#report_error(printf('Command timed out: %s',
          \ type(a:cmd) == type([]) ? join(a:cmd) : a:cmd))
    call jobstop(jobid)
  elseif s:shell_error != 0
    call health#report_error(printf("Command error (%d) %s: %s", jobid,
          \ type(a:cmd) == type([]) ? join(a:cmd) : a:cmd,
          \ opts.output))
  endif

  return opts.output
endfunction

function! s:systemlist(cmd, ...) abort
  let stdout = split(s:system(a:cmd, a:0 ? a:1 : ''), "\n")
  if a:0 > 1 && !empty(a:2)
    return filter(stdout, '!empty(v:val)')
  endif
  return stdout
endfunction

" Fetch the contents of a URL.
function! s:download(url) abort
  if executable('curl')
    let rv = s:system(['curl', '-sL', a:url])
    return s:shell_error ? 'curl error: '.s:shell_error : rv
  elseif executable('python')
    let script = "
          \try:\n
          \    from urllib.request import urlopen\n
          \except ImportError:\n
          \    from urllib2 import urlopen\n
          \\n
          \response = urlopen('".a:url."')\n
          \print(response.read().decode('utf8'))\n
          \"
    let rv = s:system(['python', '-c', script])
    return empty(rv) && s:shell_error
          \ ? 'python urllib.request error: '.s:shell_error
          \ : rv
  endif
  return 'missing `curl` and `python`, cannot make pypi request'
endfunction

" Check for clipboard tools.
function! s:check_clipboard() abort
  call health#report_start('Clipboard')

  let clipboard_tool = provider#clipboard#Executable()
  if empty(clipboard_tool)
    call health#report_warn(
          \ "No clipboard tool found. Using the system clipboard won't work.",
          \ ['See |clipboard|.'])
  else
    call health#report_ok('Clipboard tool found: '. clipboard_tool)
  endif
endfunction

" Get the latest Neovim Python client version from PyPI.
function! s:latest_pypi_version() abort
  let pypi_version = 'unable to get pypi response'
  let pypi_response = s:download('https://pypi.python.org/pypi/neovim/json')
  if !empty(pypi_response)
    try
      let pypi_data = json_decode(pypi_response)
    catch /E474/
      return 'error: '.pypi_response
    endtry
    let pypi_version = get(get(pypi_data, 'info', {}), 'version', 'unable to parse')
  endif
  return pypi_version
endfunction

" Get version information using the specified interpreter.  The interpreter is
" used directly in case breaking changes were introduced since the last time
" Neovim's Python client was updated.
"
" Returns: [
"     {python executable version},
"     {current nvim version},
"     {current pypi nvim status},
"     {installed version status}
" ]
function! s:version_info(python) abort
  let pypi_version = s:latest_pypi_version()
  let python_version = s:trim(s:system([
        \ a:python,
        \ '-c',
        \ 'import sys; print(".".join(str(x) for x in sys.version_info[:3]))',
        \ ]))

  if empty(python_version)
    let python_version = 'unable to parse python response'
  endif

  let nvim_path = s:trim(s:system([
        \ a:python,
        \ '-c',
        \ 'import neovim; print(neovim.__file__)']))
  let nvim_path = s:shell_error ? '' : nvim_path

  if empty(nvim_path)
    return [python_version, 'unable to find nvim executable', pypi_version, 'unable to get nvim executable']
  endif

  " Assuming that multiple versions of a package are installed, sort them
  " numerically in descending order.
  function! s:compare(metapath1, metapath2)
    let a = matchstr(fnamemodify(a:metapath1, ':p:h:t'), '[0-9.]\+')
    let b = matchstr(fnamemodify(a:metapath2, ':p:h:t'), '[0-9.]\+')
    return a == b ? 0 : a > b ? 1 : -1
  endfunction

  let nvim_version = 'unable to find nvim version'
  let base = fnamemodify(nvim_path, ':h')
  let metas = glob(base.'-*/METADATA', 1, 1) + glob(base.'-*/PKG-INFO', 1, 1)
  let metas = sort(metas, 's:compare')

  if !empty(metas)
    for meta_line in readfile(metas[0])
      if meta_line =~# '^Version:'
        let nvim_version = matchstr(meta_line, '^Version: \zs\S\+')
        break
      endif
    endfor
  endif

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

function! s:check_python(version) abort
  call health#report_start('Python ' . a:version . ' provider')

  let python_bin_name = 'python'.(a:version == 2 ? '' : '3')
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

      let python_bin = s:trim(s:system(
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
      let pyenv_prefix = resolve(s:trim(s:system([pyenv, 'prefix'])))
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
    call health#report_info(printf('%s-neovim version: %s', python_bin_name, current))

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
      call health#report_warn('Unable to contact PyPI.')
      call health#report_error('HTTP request failed: '.latest)
    endif

    if s:is_bad_response(status)
      call health#report_warn(printf('Latest %s-neovim is NOT installed: %s',
            \ python_bin_name, latest))
    elseif !s:is_bad_response(latest)
      call health#report_ok(printf('Latest %s-neovim is installed: %s',
            \ python_bin_name, latest))
    endif
  endif

endfunction

function! s:check_ruby() abort
  call health#report_start('Ruby provider')
  let ruby_version = 'not found'
  if executable('ruby')
    let ruby_version = s:systemlist('ruby -v')[0]
  endif
  let ruby_prog    = provider#ruby#Detect()
  let suggestions  =
        \ ['Install or upgrade the neovim RubyGem using `gem install neovim`.']

  if empty(ruby_prog)
    let ruby_prog = 'not found'
    let prog_vers = 'not found'
    call health#report_error('Missing Neovim RubyGem', suggestions)
  else
    silent let latest_gem = get(s:systemlist("gem list -ra '^neovim$' 2>/dev/null | " .
          \ "awk -F'[()]' '{print $2}' | " .
          \ 'cut -d, -f1'), 0, 'not found')
    let latest_desc = ' (latest: ' . latest_gem . ')'

    silent let prog_vers = s:systemlist(ruby_prog . ' --version')[0]
    if s:shell_error
      let prog_vers = 'not found' . latest_desc
      call health#report_warn('Neovim RubyGem is not up-to-date.', suggestions)
    elseif s:version_cmp(prog_vers, latest_gem) == -1
      let prog_vers .= latest_desc
      call health#report_warn('Neovim RubyGem is not up-to-date.', suggestions)
    else
      call health#report_ok('Found up-to-date neovim RubyGem')
    endif
  endif

  call health#report_info('Ruby Version: ' . ruby_version)
  call health#report_info('Host Executable: ' . ruby_prog)
  call health#report_info('Host Version: ' . prog_vers)
endfunction

function! health#provider#check() abort
  call s:check_clipboard()
  call s:check_python(2)
  call s:check_python(3)
  call s:check_ruby()
endfunction
