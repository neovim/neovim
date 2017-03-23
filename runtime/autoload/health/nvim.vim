let s:suggest_faq = 'See https://github.com/neovim/neovim/wiki/FAQ'

function! s:check_config() abort
  call health#report_start('Configuration')
  if !get(g:, 'loaded_sensible', 0)
    call health#report_ok('no issues found')
  else
    let sensible_pi = globpath(&runtimepath, '**/sensible.vim', 1, 1)
    call health#report_info("found sensible.vim plugin:\n".join(sensible_pi, "\n"))
    call health#report_error("sensible.vim plugin is not needed; Nvim has the same defaults built-in."
      \ ." Also, sensible.vim sets 'ttimeoutlen' to a sub-optimal value.",
      \ ["Remove sensible.vim plugin, or wrap it in a `if !has('nvim')` check."])
  endif
endfunction

" Load the remote plugin manifest file and check for unregistered plugins
function! s:check_rplugin_manifest() abort
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
        if script =~# '[\/]__init__\.py$'
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

function! s:check_performance() abort
  call health#report_start('Performance')

  " check buildtype
  let buildtype = matchstr(execute('version'), '\v\cbuild type:?\s*[^\n\r\t ]+')
  if empty(buildtype)
    call health#report_error('failed to get build type from :version')
  elseif buildtype =~# '\v(MinSizeRel|Release|RelWithDebInfo)'
    call health#report_ok(buildtype)
  else
    call health#report_info(buildtype)
    call health#report_warn(
          \ "Non-optimized build-type. Nvim will be slower.",
          \ ["Install a different Nvim package, or rebuild with `CMAKE_BUILD_TYPE=RelWithDebInfo`.",
          \  s:suggest_faq])
  endif
endfunction

function! s:check_tmux() abort
  if empty($TMUX) || !executable('tmux')
    return
  endif
  call health#report_start('tmux')

  " check escape-time
  let suggestions = ["Set escape-time in ~/.tmux.conf:\nset-option -sg escape-time 10",
        \ s:suggest_faq]
  let cmd = 'tmux show-option -qvgs escape-time'
  let out = system(cmd)
  let tmux_esc_time = substitute(out, '\v(\s|\r|\n)', '', 'g')
  if v:shell_error
    call health#report_error('command failed: '.cmd."\n".out)
  elseif empty(tmux_esc_time)
    call health#report_error('escape-time is not set', suggestions)
  elseif tmux_esc_time > 300
    call health#report_error(
        \ 'escape-time ('.tmux_esc_time.') is higher than 300ms', suggestions)
  else
    call health#report_ok('escape-time: '.tmux_esc_time.'ms')
  endif

  " check default-terminal and $TERM
  call health#report_info('$TERM: '.$TERM)
  let cmd = 'tmux show-option -qvg default-terminal'
  let out = system(cmd)
  let tmux_default_term = substitute(out, '\v(\s|\r|\n)', '', 'g')
  if empty(tmux_default_term)
    let cmd = 'tmux show-option -qvgs default-terminal'
    let out = system(cmd)
    let tmux_default_term = substitute(out, '\v(\s|\r|\n)', '', 'g')
  endif

  if v:shell_error
    call health#report_error('command failed: '.cmd."\n".out)
  elseif tmux_default_term !=# $TERM
    call health#report_info('default-terminal: '.tmux_default_term)
    call health#report_error(
          \ '$TERM differs from the tmux `default-terminal` setting. Colors might look wrong.',
          \ ['$TERM may have been set by some rc (.bashrc, .zshrc, ...).'])
  elseif $TERM !~# '\v(tmux-256color|screen-256color)'
    call health#report_error(
          \ '$TERM should be "screen-256color" or "tmux-256color" in tmux. Colors might look wrong.',
          \ ["Set default-terminal in ~/.tmux.conf:\nset-option -g default-terminal \"screen-256color\"",
          \  s:suggest_faq])
  endif
endfunction

function! s:check_terminal() abort
  if !executable('infocmp')
    return
  endif
  call health#report_start('terminal')
  let cmd = 'infocmp -L'
  let out = system(cmd)
  let kbs_entry   = matchstr(out, 'key_backspace=[^,[:space:]]*')
  let kdch1_entry = matchstr(out, 'key_dc=[^,[:space:]]*')

  if v:shell_error
    call health#report_error('command failed: '.cmd."\n".out)
  else
    call health#report_info('key_backspace (kbs) terminfo entry: '
        \ .(empty(kbs_entry) ? '? (not found)' : kbs_entry))
    call health#report_info('key_dc (kdch1) terminfo entry: '
        \ .(empty(kbs_entry) ? '? (not found)' : kdch1_entry))
  endif
endfunction

function! health#nvim#check() abort
  call s:check_config()
  call s:check_performance()
  call s:check_rplugin_manifest()
  call s:check_terminal()
  call s:check_tmux()
endfunction
