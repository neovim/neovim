let s:shell_error = 0

function! s:is_bad_response(s) abort
  return a:s =~? '\v(^unable)|(^error)|(^outdated)'
endfunction

function! s:trim(s) abort
  return substitute(a:s, '^\_s*\|\_s*$', '', 'g')
endfunction

" Convert '\' to '/'. Collapse '//' and '/./'.
function! s:normalize_path(s) abort
  return substitute(substitute(a:s, '\', '/', 'g'), '/\./\|/\+', '/', 'g')
endfunction

" Returns TRUE if `cmd` exits with success, else FALSE.
function! s:cmd_ok(cmd) abort
  call system(a:cmd)
  return v:shell_error == 0
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
function! s:system_handler(jobid, data, event) dict abort
  if a:event ==# 'stderr'
    if self.add_stderr_to_output
      let self.output .= join(a:data, '')
    else
      let self.stderr .= join(a:data, '')
    endif
  elseif a:event ==# 'stdout'
    let self.output .= join(a:data, '')
  elseif a:event ==# 'exit'
    let s:shell_error = a:data
  endif
endfunction

" Attempts to construct a shell command from an args list.
" Only for display, to help users debug a failed command.
function! s:shellify(cmd) abort
  if type(a:cmd) != type([])
    return a:cmd
  endif
  return join(map(copy(a:cmd),
    \'v:val =~# ''\m[^\-.a-zA-Z_/]'' ? shellescape(v:val) : v:val'), ' ')
endfunction

" Run a system command and timeout after 30 seconds.
function! s:system(cmd, ...) abort
  let stdin = a:0 ? a:1 : ''
  let ignore_error = a:0 > 2 ? a:3 : 0
  let opts = {
        \ 'add_stderr_to_output': a:0 > 1 ? a:2 : 0,
        \ 'output': '',
        \ 'stderr': '',
        \ 'on_stdout': function('s:system_handler'),
        \ 'on_stderr': function('s:system_handler'),
        \ 'on_exit': function('s:system_handler'),
        \ }
  let jobid = jobstart(a:cmd, opts)

  if jobid < 1
    call health#report_error(printf('Command error (job=%d): `%s` (in %s)',
          \ jobid, s:shellify(a:cmd), string(getcwd())))
    let s:shell_error = 1
    return opts.output
  endif

  if !empty(stdin)
    call jobsend(jobid, stdin)
  endif

  let res = jobwait([jobid], 30000)
  if res[0] == -1
    call health#report_error(printf('Command timed out: %s', s:shellify(a:cmd)))
    call jobstop(jobid)
  elseif s:shell_error != 0 && !ignore_error
    let emsg = printf("Command error (job=%d, exit code %d): `%s` (in %s)",
          \ jobid, s:shell_error, s:shellify(a:cmd), string(getcwd()))
    if !empty(opts.output)
      let emsg .= "\noutput: " . opts.output
    end
    if !empty(opts.stderr)
      let emsg .= "\nstderr: " . opts.stderr
    end
    call health#report_error(emsg)
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
  let has_curl = executable('curl')
  if has_curl && system(['curl', '-V']) =~# 'Protocols:.*https'
    let rv = s:system(['curl', '-sL', a:url], '', 1, 1)
    return s:shell_error ? 'curl error with '.a:url.': '.s:shell_error : rv
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
  return 'missing `curl` '
          \ .(has_curl ? '(with HTTPS support) ' : '')
          \ .'and `python`, cannot make web request'
endfunction

" Check for clipboard tools.
function! s:check_clipboard() abort
  call health#report_start('Clipboard (optional)')

  if !empty($TMUX) && executable('tmux') && executable('pbpaste') && !s:cmd_ok('pbpaste')
    let tmux_version = matchstr(system('tmux -V'), '\d\+\.\d\+')
    call health#report_error('pbcopy does not work with tmux version: '.tmux_version,
          \ ['Install tmux 2.6+.  https://superuser.com/q/231130',
          \  'or use tmux with reattach-to-user-namespace.  https://superuser.com/a/413233'])
  endif

  let clipboard_tool = provider#clipboard#Executable()
  if exists('g:clipboard') && empty(clipboard_tool)
    call health#report_error(
          \ provider#clipboard#Error(),
          \ ["Use the example in :help g:clipboard as a template, or don't set g:clipboard at all."])
  elseif empty(clipboard_tool)
    call health#report_warn(
          \ 'No clipboard tool found. Clipboard registers (`"+` and `"*`) will not work.',
          \ [':help clipboard'])
  else
    call health#report_ok('Clipboard tool found: '. clipboard_tool)
  endif
endfunction

" Get the latest Nvim Python client (pynvim) version from PyPI.
function! s:latest_pypi_version() abort
  let pypi_version = 'unable to get pypi response'
  let pypi_response = s:download('https://pypi.python.org/pypi/pynvim/json')
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
" Nvim's Python client was updated.
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
    let python_version = 'unable to parse '.a:python.' response'
  endif

  let nvim_path = s:trim(s:system([
        \ a:python, '-c',
        \ 'import sys; ' .
        \ 'sys.path = list(filter(lambda x: x != "", sys.path)); ' .
        \ 'import neovim; print(neovim.__file__)']))
  if s:shell_error || empty(nvim_path)
    return [python_version, 'unable to load neovim Python module', pypi_version,
          \ nvim_path]
  endif

  " Assuming that multiple versions of a package are installed, sort them
  " numerically in descending order.
  function! s:compare(metapath1, metapath2) abort
    let a = matchstr(fnamemodify(a:metapath1, ':p:h:t'), '[0-9.]\+')
    let b = matchstr(fnamemodify(a:metapath2, ':p:h:t'), '[0-9.]\+')
    return a == b ? 0 : a > b ? 1 : -1
  endfunction

  " Try to get neovim.VERSION (added in 0.1.11dev).
  let nvim_version = s:system([a:python, '-c',
        \ 'from neovim import VERSION as v; '.
        \ 'print("{}.{}.{}{}".format(v.major, v.minor, v.patch, v.prerelease))'],
        \ '', 1, 1)
  if empty(nvim_version)
    let nvim_version = 'unable to find pynvim module version'
    let base = fnamemodify(nvim_path, ':h')
    let metas = glob(base.'-*/METADATA', 1, 1)
          \ + glob(base.'-*/PKG-INFO', 1, 1)
          \ + glob(base.'.egg-info/PKG-INFO', 1, 1)
    let metas = sort(metas, 's:compare')

    if !empty(metas)
      for meta_line in readfile(metas[0])
        if meta_line =~# '^Version:'
          let nvim_version = matchstr(meta_line, '^Version: \zs\S\+')
          break
        endif
      endfor
    endif
  endif

  let nvim_path_base = fnamemodify(nvim_path, ':~:h')
  let version_status = 'unknown; '.nvim_path_base
  if !s:is_bad_response(nvim_version) && !s:is_bad_response(pypi_version)
    if s:version_cmp(nvim_version, pypi_version) == -1
      let version_status = 'outdated; from '.nvim_path_base
    else
      let version_status = 'up to date'
    endif
  endif

  return [python_version, nvim_version, pypi_version, version_status]
endfunction

" Check the Python interpreter's usability.
function! s:check_bin(bin) abort
  if !filereadable(a:bin) && (!has('win32') || !filereadable(a:bin.'.exe'))
    call health#report_error(printf('"%s" was not found.', a:bin))
    return 0
  elseif executable(a:bin) != 1
    call health#report_error(printf('"%s" is not executable.', a:bin))
    return 0
  endif
  return 1
endfunction

" Check "loaded" var for given a:provider.
" Returns 1 if the caller should return (skip checks).
function! s:disabled_via_loaded_var(provider) abort
  let loaded_var = 'g:loaded_'.a:provider.'_provider'
  if exists(loaded_var) && !exists('*provider#'.a:provider.'#Call')
    let v = eval(loaded_var)
    if 0 is v
      call health#report_info('Disabled ('.loaded_var.'='.v.').')
      return 1
    else
      call health#report_info('Disabled ('.loaded_var.'='.v.').  This might be due to some previous error.')
    endif
  endif
  return 0
endfunction

function! s:check_python(version) abort
  call health#report_start('Python ' . a:version . ' provider (optional)')

  let pyname = 'python'.(a:version == 2 ? '' : '3')
  let python_exe = ''
  let venv = exists('$VIRTUAL_ENV') ? resolve($VIRTUAL_ENV) : ''
  let host_prog_var = pyname.'_host_prog'
  let python_multiple = []

  if s:disabled_via_loaded_var(pyname)
    return
  endif

  let [pyenv, pyenv_root] = s:check_for_pyenv()

  if exists('g:'.host_prog_var)
    call health#report_info(printf('Using: g:%s = "%s"', host_prog_var, get(g:, host_prog_var)))
  endif

  let [pyname, pythonx_errors] = provider#pythonx#Detect(a:version)

  if empty(pyname)
    call health#report_warn('No Python executable found that can `import neovim`. '
            \ . 'Using the first available executable for diagnostics.')
  elseif exists('g:'.host_prog_var)
    let python_exe = pyname
  endif

  " No Python executable could `import neovim`, or host_prog_var was used.
  if !empty(pythonx_errors)
    call health#report_error('Python provider error:', pythonx_errors)

  elseif !empty(pyname) && empty(python_exe)
    if !exists('g:'.host_prog_var)
      call health#report_info(printf('`g:%s` is not set.  Searching for '
            \ . '%s in the environment.', host_prog_var, pyname))
    endif

    if !empty(pyenv)
      let python_exe = s:trim(s:system([pyenv, 'which', pyname], '', 1))

      if empty(python_exe)
        call health#report_warn(printf('pyenv could not find %s.', pyname))
      endif
    endif

    if empty(python_exe)
      let python_exe = exepath(pyname)

      if exists('$PATH')
        for path in split($PATH, has('win32') ? ';' : ':')
          let path_bin = s:normalize_path(path.'/'.pyname)
          if path_bin != s:normalize_path(python_exe)
                \ && index(python_multiple, path_bin) == -1
                \ && executable(path_bin)
            call add(python_multiple, path_bin)
          endif
        endfor

        if len(python_multiple)
          " This is worth noting since the user may install something
          " that changes $PATH, like homebrew.
          call health#report_info(printf('Multiple %s executables found.  '
                \ . 'Set `g:%s` to avoid surprises.', pyname, host_prog_var))
        endif

        if python_exe =~# '\<shims\>'
          call health#report_warn(printf('`%s` appears to be a pyenv shim.', python_exe), [
                      \ '`pyenv` is not in $PATH, your pyenv installation is broken. '
                      \ .'Set `g:'.host_prog_var.'` to avoid surprises.',
                      \ ])
        endif
      endif
    endif
  endif

  if !empty(python_exe) && !exists('g:'.host_prog_var)
    if empty(venv) && !empty(pyenv)
          \ && !empty(pyenv_root) && resolve(python_exe) !~# '^'.pyenv_root.'/'
      call health#report_warn('pyenv is not set up optimally.', [
            \ printf('Create a virtualenv specifically '
            \ . 'for Nvim using pyenv, and set `g:%s`.  This will avoid '
            \ . 'the need to install the pynvim module in each '
            \ . 'version/virtualenv.', host_prog_var)
            \ ])
    elseif !empty(venv)
      if !empty(pyenv_root)
        let venv_root = pyenv_root
      else
        let venv_root = fnamemodify(venv, ':h')
      endif

      if resolve(python_exe) !~# '^'.venv_root.'/'
        call health#report_warn('Your virtualenv is not set up optimally.', [
              \ printf('Create a virtualenv specifically '
              \ . 'for Nvim and use `g:%s`.  This will avoid '
              \ . 'the need to install the pynvim module in each '
              \ . 'virtualenv.', host_prog_var)
              \ ])
      endif
    endif
  endif

  if empty(python_exe) && !empty(pyname)
    " An error message should have already printed.
    call health#report_error(printf('`%s` was not found.', pyname))
  elseif !empty(python_exe) && !s:check_bin(python_exe)
    let python_exe = ''
  endif

  " Diagnostic output
  call health#report_info('Executable: ' . (empty(python_exe) ? 'Not found' : python_exe))
  if len(python_multiple)
    for path_bin in python_multiple
      call health#report_info('Other python executable: ' . path_bin)
    endfor
  endif

  if empty(python_exe)
    " No Python executable can import 'neovim'. Check if any Python executable
    " can import 'pynvim'. If so, that Python failed to import 'neovim' as
    " well, which is most probably due to a failed pip upgrade:
    " https://github.com/neovim/neovim/wiki/Following-HEAD#20181118
    let [pynvim_exe, errors] = provider#pythonx#DetectByModule('pynvim', a:version)
    if !empty(pynvim_exe)
      call health#report_error(
            \ 'Detected pip upgrade failure: Python executable can import "pynvim" but '
            \ . 'not "neovim": '. pynvim_exe,
            \ "Use that Python version to reinstall \"pynvim\" and optionally \"neovim\".\n"
            \ . pynvim_exe ." -m pip uninstall pynvim neovim\n"
            \ . pynvim_exe ." -m pip install pynvim\n"
            \ . pynvim_exe ." -m pip install neovim  # only if needed by third-party software")
    endif
  else
    let [pyversion, current, latest, status] = s:version_info(python_exe)

    if a:version != str2nr(pyversion)
      call health#report_warn('Unexpected Python version.' .
                  \ ' This could lead to confusing error messages.')
    endif

    call health#report_info('Python version: ' . pyversion)

    if s:is_bad_response(status)
      call health#report_info(printf('pynvim version: %s (%s)', current, status))
    else
      call health#report_info(printf('pynvim version: %s', current))
    endif

    if s:is_bad_response(current)
      call health#report_error(
        \ "pynvim is not installed.\nError: ".current,
        \ ['Run in shell: '. python_exe .' -m pip install pynvim'])
    endif

    if s:is_bad_response(latest)
      call health#report_warn('Could not contact PyPI to get latest version.')
      call health#report_error('HTTP request failed: '.latest)
    elseif s:is_bad_response(status)
      call health#report_warn(printf('Latest pynvim is NOT installed: %s', latest))
    elseif !s:is_bad_response(current)
      call health#report_ok(printf('Latest pynvim is installed.'))
    endif
  endif
endfunction

" Check if pyenv is available and a valid pyenv root can be found, then return
" their respective paths. If either of those is invalid, return two empty
" strings, effectivly ignoring pyenv.
function! s:check_for_pyenv() abort
  let pyenv_path = resolve(exepath('pyenv'))

  if empty(pyenv_path)
    return ['', '']
  endif

  call health#report_info('pyenv: Path: '. pyenv_path)

  let pyenv_root = exists('$PYENV_ROOT') ? resolve($PYENV_ROOT) : ''

  if empty(pyenv_root)
    let pyenv_root = s:trim(s:system([pyenv_path, 'root']))
    call health#report_info('pyenv: $PYENV_ROOT is not set. Infer from `pyenv root`.')
  endif

  if !isdirectory(pyenv_root)
    call health#report_warn(
          \ printf('pyenv: Root does not exist: %s. '
          \ . 'Ignoring pyenv for all following checks.', pyenv_root))
    return ['', '']
  endif

  call health#report_info('pyenv: Root: '.pyenv_root)

  return [pyenv_path, pyenv_root]
endfunction

" Resolves Python executable path by invoking and checking `sys.executable`.
function! s:python_exepath(invocation) abort
  return s:normalize_path(system(fnameescape(a:invocation)
    \ . ' -c "import sys; sys.stdout.write(sys.executable)"'))
endfunction

" Checks that $VIRTUAL_ENV Python executables are found at front of $PATH in
" Nvim and subshells.
function! s:check_virtualenv() abort
  call health#report_start('Python virtualenv')
  if !exists('$VIRTUAL_ENV')
    call health#report_ok('no $VIRTUAL_ENV')
    return
  endif
  let errors = []
  " Keep hints as dict keys in order to discard duplicates.
  let hints = {}
  " The virtualenv should contain some Python executables, and those
  " executables should be first both on Nvim's $PATH and the $PATH of
  " subshells launched from Nvim.
  let bin_dir = has('win32') ? '/Scripts' : '/bin'
  let venv_bins = glob($VIRTUAL_ENV . bin_dir . '/python*', v:true, v:true)
  " XXX: Remove irrelevant executables found in bin/.
  let venv_bins = filter(venv_bins, 'v:val !~# "python-config"')
  if len(venv_bins)
    for venv_bin in venv_bins
      let venv_bin = s:normalize_path(venv_bin)
      let py_bin_basename = fnamemodify(venv_bin, ':t')
      let nvim_py_bin = s:python_exepath(exepath(py_bin_basename))
      let subshell_py_bin = s:python_exepath(py_bin_basename)
      if venv_bin !=# nvim_py_bin
        call add(errors, '$PATH yields this '.py_bin_basename.' executable: '.nvim_py_bin)
        let hint = '$PATH ambiguities arise if the virtualenv is not '
          \.'properly activated prior to launching Nvim. Close Nvim, activate the virtualenv, '
          \.'check that invoking Python from the command line launches the correct one, '
          \.'then relaunch Nvim.'
        let hints[hint] = v:true
      endif
      if venv_bin !=# subshell_py_bin
        call add(errors, '$PATH in subshells yields this '
          \.py_bin_basename . ' executable: '.subshell_py_bin)
        let hint = '$PATH ambiguities in subshells typically are '
          \.'caused by your shell config overriding the $PATH previously set by the '
          \.'virtualenv. Either prevent them from doing so, or use this workaround: '
          \.'https://vi.stackexchange.com/a/7654'
        let hints[hint] = v:true
      endif
    endfor
  else
    call add(errors, 'no Python executables found in the virtualenv '.bin_dir.' directory.')
  endif

  let msg = '$VIRTUAL_ENV is set to: '.$VIRTUAL_ENV
  if len(errors)
    if len(venv_bins)
      let msg .= "\nAnd its ".bin_dir.' directory contains: '
        \.join(map(venv_bins, "fnamemodify(v:val, ':t')"), ', ')
    endif
    let conj = "\nBut "
    for error in errors
      let msg .= conj.error
      let conj = "\nAnd "
    endfor
    let msg .= "\nSo invoking Python may lead to unexpected results."
    call health#report_warn(msg, keys(hints))
  else
    call health#report_info(msg)
    call health#report_info('Python version: '
      \.system('python -c "import platform, sys; sys.stdout.write(platform.python_version())"'))
    call health#report_ok('$VIRTUAL_ENV provides :!python.')
  endif
endfunction

function! s:check_ruby() abort
  call health#report_start('Ruby provider (optional)')

  if s:disabled_via_loaded_var('ruby')
    return
  endif

  if !executable('ruby') || !executable('gem')
    call health#report_warn(
          \ '`ruby` and `gem` must be in $PATH.',
          \ ['Install Ruby and verify that `ruby` and `gem` commands work.'])
    return
  endif
  call health#report_info('Ruby: '. s:system('ruby -v'))

  let [host, err] = provider#ruby#Detect()
  if empty(host)
    call health#report_warn('`neovim-ruby-host` not found.',
          \ ['Run `gem install neovim` to ensure the neovim RubyGem is installed.',
          \  'Run `gem environment` to ensure the gem bin directory is in $PATH.',
          \  'If you are using rvm/rbenv/chruby, try "rehashing".',
          \  'See :help g:ruby_host_prog for non-standard gem installations.'])
    return
  endif
  call health#report_info('Host: '. host)

  let latest_gem_cmd = has('win32') ? 'cmd /c gem list -ra "^^neovim$"' : 'gem list -ra ^neovim$'
  let latest_gem = s:system(split(latest_gem_cmd))
  if s:shell_error || empty(latest_gem)
    call health#report_error('Failed to run: '. latest_gem_cmd,
          \ ["Make sure you're connected to the internet.",
          \  'Are you behind a firewall or proxy?'])
    return
  endif
  let latest_gem = get(split(latest_gem, 'neovim (\|, \|)$' ), 0, 'not found')

  let current_gem_cmd = host .' --version'
  let current_gem = s:system(current_gem_cmd)
  if s:shell_error
    call health#report_error('Failed to run: '. current_gem_cmd,
          \ ['Report this issue with the output of: ', current_gem_cmd])
    return
  endif

  if s:version_cmp(current_gem, latest_gem) == -1
    call health#report_warn(
          \ printf('Gem "neovim" is out-of-date. Installed: %s, latest: %s',
          \ current_gem, latest_gem),
          \ ['Run in shell: gem update neovim'])
  else
    call health#report_ok('Latest "neovim" gem is installed: '. current_gem)
  endif
endfunction

function! s:check_node() abort
  call health#report_start('Node.js provider (optional)')

  if s:disabled_via_loaded_var('node')
    return
  endif

  if !executable('node') || (!executable('npm') && !executable('yarn'))
    call health#report_warn(
          \ '`node` and `npm` (or `yarn`) must be in $PATH.',
          \ ['Install Node.js and verify that `node` and `npm` (or `yarn`) commands work.'])
    return
  endif
  let node_v = get(split(s:system('node -v'), "\n"), 0, '')
  call health#report_info('Node.js: '. node_v)
  if s:shell_error || s:version_cmp(node_v[1:], '6.0.0') < 0
    call health#report_warn('Nvim node.js host does not support '.node_v)
    " Skip further checks, they are nonsense if nodejs is too old.
    return
  endif
  if !provider#node#can_inspect()
    call health#report_warn('node.js on this system does not support --inspect-brk so $NVIM_NODE_HOST_DEBUG is ignored.')
  endif

  let [host, err] = provider#node#Detect()
  if empty(host)
    call health#report_warn('Missing "neovim" npm (or yarn) package.',
          \ ['Run in shell: npm install -g neovim',
          \  'Run in shell (if you use yarn): yarn global add neovim'])
    return
  endif
  call health#report_info('Nvim node.js host: '. host)

  let manager = executable('npm') ? 'npm' : 'yarn'
  let latest_npm_cmd = has('win32') ?
        \ 'cmd /c '. manager .' info neovim --json' :
        \ manager .' info neovim --json'
  let latest_npm = s:system(split(latest_npm_cmd))
  if s:shell_error || empty(latest_npm)
    call health#report_error('Failed to run: '. latest_npm_cmd,
          \ ["Make sure you're connected to the internet.",
          \  'Are you behind a firewall or proxy?'])
    return
  endif
  try
    let pkg_data = json_decode(latest_npm)
  catch /E474/
    return 'error: '.latest_npm
  endtry
  let latest_npm = get(get(pkg_data, 'dist-tags', {}), 'latest', 'unable to parse')

  let current_npm_cmd = ['node', host, '--version']
  let current_npm = s:system(current_npm_cmd)
  if s:shell_error
    call health#report_error('Failed to run: '. string(current_npm_cmd),
          \ ['Report this issue with the output of: ', string(current_npm_cmd)])
    return
  endif

  if s:version_cmp(current_npm, latest_npm) == -1
    call health#report_warn(
          \ printf('Package "neovim" is out-of-date. Installed: %s, latest: %s',
          \ current_npm, latest_npm),
          \ ['Run in shell: npm install -g neovim',
          \  'Run in shell (if you use yarn): yarn global add neovim'])
  else
    call health#report_ok('Latest "neovim" npm/yarn package is installed: '. current_npm)
  endif
endfunction

function! s:check_perl() abort
  call health#report_start('Perl provider (optional)')

  if s:disabled_via_loaded_var('perl')
    return
  endif

  let [perl_exec, perl_errors] = provider#perl#Detect()
  if empty(perl_exec)
    if !empty(perl_errors)
      call health#report_error('perl provider error:', perl_errors)
	else
      call health#report_warn('No usable perl executable found')
    endif
	return
  endif

  call health#report_info('perl executable: '. perl_exec)

  " we cannot use cpanm that is on the path, as it may not be for the perl
  " set with g:perl_host_prog
  call s:system([perl_exec, '-W', '-MApp::cpanminus', '-e', ''])
  if s:shell_error
    return [perl_exec, '"App::cpanminus" module is not installed']
  endif

  let latest_cpan_cmd = [perl_exec,
			  \ '-MApp::cpanminus::fatscript', '-e',
			  \ 'my $app = App::cpanminus::script->new;
			  \ $app->parse_options ("--info", "-q", "Neovim::Ext");
			  \ exit $app->doit']

  let latest_cpan = s:system(latest_cpan_cmd)
  if s:shell_error || empty(latest_cpan)
    call health#report_error('Failed to run: '. latest_cpan_cmd,
          \ ["Make sure you're connected to the internet.",
          \  'Are you behind a firewall or proxy?'])
    return
  elseif latest_cpan[0] ==# '!'
    let cpanm_errs = split(latest_cpan, '!')
    if cpanm_errs[0] =~# "Can't write to "
      call health#report_warn(cpanm_errs[0], cpanm_errs[1:-2])
      " Last line is the package info
      let latest_cpan = cpanm_errs[-1]
    else
      call health#report_error('Unknown warning from command: ' . latest_cpan_cmd, cpanm_errs)
      return
    endif
  endif
  let latest_cpan = matchstr(latest_cpan, '\(\.\?\d\)\+')
  if empty(latest_cpan)
    call health#report_error('Cannot parse version number from cpanm output: ' . latest_cpan)
    return
  endif

  let current_cpan_cmd = [perl_exec, '-W', '-MNeovim::Ext', '-e', 'print $Neovim::Ext::VERSION']
  let current_cpan = s:system(current_cpan_cmd)
  if s:shell_error
    call health#report_error('Failed to run: '. string(current_cpan_cmd),
          \ ['Report this issue with the output of: ', string(current_cpan_cmd)])
    return
  endif

  if s:version_cmp(current_cpan, latest_cpan) == -1
    call health#report_warn(
          \ printf('Module "Neovim::Ext" is out-of-date. Installed: %s, latest: %s',
          \ current_cpan, latest_cpan),
          \ ['Run in shell: cpanm -n Neovim::Ext'])
  else
    call health#report_ok('Latest "Neovim::Ext" cpan module is installed: '. current_cpan)
  endif
endfunction

function! health#provider#check() abort
  call s:check_clipboard()
  call s:check_python(2)
  call s:check_python(3)
  call s:check_virtualenv()
  call s:check_ruby()
  call s:check_node()
  call s:check_perl()
endfunction
