let s:shell_error = 0

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
  call s:check_perl()
endfunction
