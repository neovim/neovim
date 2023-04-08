let s:shell_error = 0

" Convert '\' to '/'. Collapse '//' and '/./'.
function! s:normalize_path(s) abort
  return substitute(substitute(a:s, '\', '/', 'g'), '/\./\|/\+', '/', 'g')
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
          \.'https://vi.stackexchange.com/a/34996'
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
  call health#report_info('Ruby: '. s:system(['ruby', '-v']))

  let [host, err] = provider#ruby#Detect()
  if empty(host)
    call health#report_warn('`neovim-ruby-host` not found.',
          \ ['Run `gem install neovim` to ensure the neovim RubyGem is installed.',
          \  'Run `gem environment` to ensure the gem bin directory is in $PATH.',
          \  'If you are using rvm/rbenv/chruby, try "rehashing".',
          \  'See :help g:ruby_host_prog for non-standard gem installations.',
          \  'You may disable this provider (and warning) by adding `let g:loaded_ruby_provider = 0` to your init.vim'])
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

  let current_gem_cmd = [host, '--version']
  let current_gem = s:system(current_gem_cmd)
  if s:shell_error
    call health#report_error('Failed to run: '. join(current_gem_cmd),
          \ ['Report this issue with the output of: ', join(current_gem_cmd)])
    return
  endif

  if v:lua.vim.version.lt(current_gem, latest_gem)
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

  if !executable('node') || (!executable('npm') && !executable('yarn') && !executable('pnpm'))
    call health#report_warn(
          \ '`node` and `npm` (or `yarn`, `pnpm`) must be in $PATH.',
          \ ['Install Node.js and verify that `node` and `npm` (or `yarn`, `pnpm`) commands work.'])
    return
  endif
  let node_v = get(split(s:system(['node', '-v']), "\n"), 0, '')
  call health#report_info('Node.js: '. node_v)
  if s:shell_error || v:lua.vim.version.lt(node_v[1:], '6.0.0')
    call health#report_warn('Nvim node.js host does not support Node '.node_v)
    " Skip further checks, they are nonsense if nodejs is too old.
    return
  endif
  if !provider#node#can_inspect()
    call health#report_warn('node.js on this system does not support --inspect-brk so $NVIM_NODE_HOST_DEBUG is ignored.')
  endif

  let [host, err] = provider#node#Detect()
  if empty(host)
    call health#report_warn('Missing "neovim" npm (or yarn, pnpm) package.',
          \ ['Run in shell: npm install -g neovim',
          \  'Run in shell (if you use yarn): yarn global add neovim',
          \  'Run in shell (if you use pnpm): pnpm install -g neovim',
          \  'You may disable this provider (and warning) by adding `let g:loaded_node_provider = 0` to your init.vim'])
    return
  endif
  call health#report_info('Nvim node.js host: '. host)

  let manager = 'npm'
  if executable('yarn')
    let manager = 'yarn'
  elseif executable('pnpm')
    let manager = 'pnpm'
  endif

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
    call health#report_error('Failed to run: '. join(current_npm_cmd),
          \ ['Report this issue with the output of: ', join(current_npm_cmd)])
    return
  endif

  if latest_npm !=# 'unable to parse' && v:lua.vim.version.lt(current_npm, latest_npm)
    call health#report_warn(
          \ printf('Package "neovim" is out-of-date. Installed: %s, latest: %s',
          \ current_npm, latest_npm),
          \ ['Run in shell: npm install -g neovim',
          \  'Run in shell (if you use yarn): yarn global add neovim',
          \  'Run in shell (if you use pnpm): pnpm install -g neovim'])
  else
    call health#report_ok('Latest "neovim" npm/yarn/pnpm package is installed: '. current_npm)
  endif
endfunction

function! s:check_perl() abort
  call health#report_start('Perl provider (optional)')

  if s:disabled_via_loaded_var('perl')
    return
  endif

  let [perl_exec, perl_warnings] = provider#perl#Detect()
  if empty(perl_exec)
    if !empty(perl_warnings)
      call health#report_warn(perl_warnings, ['See :help provider-perl for more information.',
            \ 'You may disable this provider (and warning) by adding `let g:loaded_perl_provider = 0` to your init.vim'])
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
    call health#report_error('Failed to run: '. join(latest_cpan_cmd, " "),
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
    call health#report_error('Failed to run: '. join(current_cpan_cmd),
          \ ['Report this issue with the output of: ', join(current_cpan_cmd)])
    return
  endif

  if v:lua.vim.version.lt(current_cpan, latest_cpan)
    call health#report_warn(
          \ printf('Module "Neovim::Ext" is out-of-date. Installed: %s, latest: %s',
          \ current_cpan, latest_cpan),
          \ ['Run in shell: cpanm -n Neovim::Ext'])
  else
    call health#report_ok('Latest "Neovim::Ext" cpan module is installed: '. current_cpan)
  endif
endfunction

function! health#provider2#check() abort
  call s:check_virtualenv()
  call s:check_ruby()
  call s:check_node()
  call s:check_perl()
endfunction
