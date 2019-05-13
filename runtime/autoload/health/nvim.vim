let s:suggest_faq = 'https://github.com/neovim/neovim/wiki/FAQ'

function! s:check_config() abort
  let ok = v:true
  call health#report_start('Configuration')

  let vimrc = empty($MYVIMRC) ? stdpath('config').'/init.vim' : $MYVIMRC
  if !filereadable(vimrc)
    let ok = v:false
    let has_vim = filereadable(expand('~/.vimrc'))
    call health#report_warn('Missing user config file: '.vimrc,
          \[ has_vim ? ':help nvim-from-vim' : ':help init.vim' ])
  endif

  " If $VIM is empty we don't care. Else make sure it is valid.
  if !empty($VIM) && !filereadable($VIM.'/runtime/doc/nvim.txt')
    let ok = v:false
    call health#report_error('$VIM is invalid: '.$VIM)
  endif

  if exists('$NVIM_TUI_ENABLE_CURSOR_SHAPE')
    let ok = v:false
    call health#report_warn('$NVIM_TUI_ENABLE_CURSOR_SHAPE is ignored in Nvim 0.2+',
          \ [ "Use the 'guicursor' option to configure cursor shape. :help 'guicursor'",
          \   'https://github.com/neovim/neovim/wiki/Following-HEAD#20170402' ])
  endif

  if v:ctype ==# 'C'
    let ok = v:false
    call health#report_error('Locale does not support UTF-8. Unicode characters may not display correctly.'
          \                  .printf("\n$LANG=%s $LC_ALL=%s $LC_CTYPE=%s", $LANG, $LC_ALL, $LC_CTYPE),
          \ [ 'If using tmux, try the -u option.',
          \   'Ensure that your terminal/shell/tmux/etc inherits the environment, or set $LANG explicitly.' ,
          \   'Configure your system locale.' ])
  endif

  if &paste
    let ok = v:false
    call health#report_error("'paste' is enabled. This option is only for pasting text.\nIt should not be set in your config.",
          \ [ 'Remove `set paste` from your init.vim, if applicable.',
          \   'Check `:verbose set paste?` to see if a plugin or script set the option.', ])
  endif

  if ok
    call health#report_ok('no issues found')
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
          let script = tr(fnamemodify(script, ':h'), '\', '/')
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
          \ 'Non-optimized build-type. Nvim will be slower.',
          \ ['Install a different Nvim package, or rebuild with `CMAKE_BUILD_TYPE=RelWithDebInfo`.',
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

  " check for RGB capabilities
  let info = system('tmux server-info')
  let has_tc = stridx(info, " Tc: (flag) true") != -1
  let has_rgb = stridx(info, " RGB: (flag) true") != -1
  if !has_tc && !has_rgb
    call health#report_warn(
          \ "Neither Tc nor RGB capability set. True colors are disabled. |'termguicolors'| won't work properly.",
          \ ["Put this in your ~/.tmux.conf and replace XXX by your $TERM outside of tmux:\nset-option -sa terminal-overrides ',XXX:RGB'",
          \  "For older tmux versions use this instead:\nset-option -ga terminal-overrides ',XXX:Tc'"])
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
  for env_var in ['XTERM_VERSION', 'VTE_VERSION', 'TERM_PROGRAM', 'COLORTERM', 'SSH_TTY']
    if exists('$'.env_var)
      call health#report_info(printf("$%s='%s'", env_var, eval('$'.env_var)))
    endif
  endfor
endfunction

function! health#nvim#check() abort
  call s:check_config()
  call s:check_performance()
  call s:check_rplugin_manifest()
  call s:check_terminal()
  call s:check_tmux()
endfunction
