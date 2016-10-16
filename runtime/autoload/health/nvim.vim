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

function! s:check_tmux() abort
  if empty($TMUX) || !executable('tmux')
    return
  endif
  call health#report_start('tmux configuration')
  let suggestions = ["Set escape-time in ~/.tmux.conf: set-option -sg escape-time 10",
        \ 'See https://github.com/neovim/neovim/wiki/FAQ']
  let cmd = 'tmux show-option -qvgs escape-time'
  let out = system(cmd)
  let tmux_esc_time = substitute(out, '\v(\s|\r|\n)', '', 'g')

  if v:shell_error
    call health#report_error('command failed: '.cmd."\n".out)
  elseif empty(tmux_esc_time)
    call health#report_error('escape-time is not set', suggestions)
  elseif tmux_esc_time > 500
    call health#report_error(
          \ 'escape-time ('.tmux_esc_time.') is higher than 300ms', suggestions)
  else
    call health#report_ok('escape-time = '.tmux_esc_time.'ms')
  endif
endfunction

function! health#nvim#check() abort
  call s:check_manifest()
  call s:check_tmux()
endfunction
