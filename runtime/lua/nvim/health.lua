local M = {}
local health = require('vim.health')

local suggest_faq = 'https://github.com/neovim/neovim/wiki/FAQ'

local function check_runtime()
  health.report_start('Runtime')
  -- Files from an old installation.
  local bad_files = {
    ['plugin/man.vim'] = false,
    ['scripts.vim'] = false,
    ['autoload/man.vim'] = false,
  }
  local bad_files_msg = ''
  for k, _ in pairs(bad_files) do
    local path = ('%s/%s'):format(vim.env.VIMRUNTIME, k)
    if vim.loop.fs_stat(path) then
      bad_files[k] = true
      bad_files_msg = ('%s%s\n'):format(bad_files_msg, path)
    end
  end

  local ok = (bad_files_msg == '')
  local info = ok and health.report_ok or health.report_info
  info(string.format('$VIMRUNTIME: %s', vim.env.VIMRUNTIME))
  if not ok then
    health.report_error(
      string.format(
        '$VIMRUNTIME has files from an old installation (this can cause weird behavior):\n%s',
        bad_files_msg
      ),
      { 'Delete $VIMRUNTIME (or uninstall Nvim), then reinstall Nvim.' }
    )
  end
end

local function check_config()
  health.report_start('Configuration')
  local ok = true
  local empty = function(o)
    return 0 ~= vim.fn.empty(o)
  end
  local filereadable = function(o)
    return 0 ~= vim.fn.filereadable(o)
  end
  local filewritable = function(o)
    return 0 ~= vim.fn.filewritable(o)
  end

  local vimrc = (
    empty(vim.env.MYVIMRC) and vim.fn.stdpath('config') .. '/init.vim' or vim.env.MYVIMRC
  )
  if not filereadable(vimrc) then
    ok = false
    local has_vim = filereadable(vim.fn.expand('~/.vimrc'))
    health.report_warn(
      (-1 == vim.fn.getfsize(vimrc) and 'Missing' or 'Unreadable') .. ' user config file: ' .. vimrc,
      { has_vim and ':help nvim-from-vim' or ':help init.vim' }
    )
  end

  -- If $VIM is empty we don't care. Else make sure it is valid.
  if not empty(vim.env.VIM) and not filereadable(vim.env.VIM .. '/runtime/doc/nvim.txt') then
    ok = false
    health.report_error('$VIM is invalid: ' .. vim.env.VIM)
  end

  if 1 == vim.fn.exists('$NVIM_TUI_ENABLE_CURSOR_SHAPE') then
    ok = false
    health.report_warn('$NVIM_TUI_ENABLE_CURSOR_SHAPE is ignored in Nvim 0.2+', {
      "Use the 'guicursor' option to configure cursor shape. :help 'guicursor'",
      'https://github.com/neovim/neovim/wiki/Following-HEAD#20170402',
    })
  end

  if vim.v.ctype == 'C' then
    ok = false
    health.report_error(
      'Locale does not support UTF-8. Unicode characters may not display correctly.'
        .. ('\n$LANG=%s $LC_ALL=%s $LC_CTYPE=%s'):format(
          vim.env.LANG,
          vim.env.LC_ALL,
          vim.env.LC_CTYPE
        ),
      {
        'If using tmux, try the -u option.',
        'Ensure that your terminal/shell/tmux/etc inherits the environment, or set $LANG explicitly.',
        'Configure your system locale.',
      }
    )
  end

  if vim.o.paste == 1 then
    ok = false
    health.report_error(
      "'paste' is enabled. This option is only for pasting text.\nIt should not be set in your config.",
      {
        'Remove `set paste` from your init.vim, if applicable.',
        'Check `:verbose set paste?` to see if a plugin or script set the option.',
      }
    )
  end

  local writeable = true
  local shadaopt = vim.fn.split(vim.o.shada, ',')
  local shadafile = (
    empty(vim.o.shada) and vim.o.shada
    or vim.fn.substitute(vim.fn.matchstr(shadaopt[#shadaopt], '^n.\\+'), '^n', '', '')
  )
  shadafile = (
    empty(vim.o.shadafile)
      and (empty(shadafile) and vim.fn.stdpath('state') .. '/shada/main.shada' or vim.fn.expand(
        shadafile
      ))
    or (vim.o.shadafile == 'NONE' and '' or vim.o.shadafile)
  )
  if not empty(shadafile) and empty(vim.fn.glob(shadafile)) then
    -- Since this may be the first time Nvim has been run, try to create a shada file.
    if not pcall(vim.cmd.wshada) then
      writeable = false
    end
  end
  if
    not writeable
    or (not empty(shadafile) and (not filereadable(shadafile) or not filewritable(shadafile)))
  then
    ok = false
    health.report_error(
      'shada file is not '
        .. ((not writeable or filereadable(shadafile)) and 'writeable' or 'readable')
        .. ':\n'
        .. shadafile
    )
  end

  if ok then
    health.report_ok('no issues found')
  end
end

local function check_performance()
  vim.api.nvim_exec([=[
  func! s:check_performance() abort
    let s:suggest_faq = ']=] .. suggest_faq .. [=['

    call health#report_start('Performance')

    " check buildtype
    let s:buildtype = matchstr(execute('version'), '\v\cbuild type:?\s*[^\n\r\t ]+')
    if empty(s:buildtype)
      call health#report_error('failed to get build type from :version')
    elseif s:buildtype =~# '\v(MinSizeRel|Release|RelWithDebInfo)'
      call health#report_ok(s:buildtype)
    else
      call health#report_info(s:buildtype)
      call health#report_warn(
            \ 'Non-optimized '.(has('debug')?'(DEBUG) ':'').'build. Nvim will be slower.',
            \ ['Install a different Nvim package, or rebuild with `CMAKE_BUILD_TYPE=RelWithDebInfo`.',
            \  s:suggest_faq])
    endif

    " check for slow shell invocation
    let s:slow_cmd_time = 1.5
    let s:start_time = reltime()
    call system('echo')
    let s:elapsed_time = reltimefloat(reltime(s:start_time))
    if s:elapsed_time > s:slow_cmd_time
      call health#report_warn(
            \ 'Slow shell invocation (took '.printf('%.2f', s:elapsed_time).' seconds).')
    endif
  endf

  call s:check_performance()
  ]=], false)
end

-- Load the remote plugin manifest file and check for unregistered plugins
local function check_rplugin_manifest()
  vim.api.nvim_exec(
    [=[
  func! s:check_rplugin_manifest() abort
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
              if !has('python3')
                let msg .= ' (python3 not available)'
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
  endf

  call s:check_rplugin_manifest()
  ]=],
    false
  )
end

local function check_tmux()
  vim.api.nvim_exec([=[
  let s:suggest_faq = ']=] .. suggest_faq .. [=['

  func! s:get_tmux_option(option) abort
    let cmd = 'tmux show-option -qvg '.a:option  " try global scope
    let out = system(split(cmd))
    let val = substitute(out, '\v(\s|\r|\n)', '', 'g')
    if v:shell_error
      call health#report_error('command failed: '.cmd."\n".out)
      return 'error'
    elseif empty(val)
      let cmd = 'tmux show-option -qvgs '.a:option  " try session scope
      let out = system(split(cmd))
      let val = substitute(out, '\v(\s|\r|\n)', '', 'g')
      if v:shell_error
        call health#report_error('command failed: '.cmd."\n".out)
        return 'error'
      endif
    endif
    return val
  endf

  func! s:check_tmux() abort
    if empty($TMUX) || !executable('tmux')
      return
    endif
    call health#report_start('tmux')

    " check escape-time
    let suggestions = ["set escape-time in ~/.tmux.conf:\nset-option -sg escape-time 10",
          \ s:suggest_faq]
    let tmux_esc_time = s:get_tmux_option('escape-time')
    if tmux_esc_time !=# 'error'
      if empty(tmux_esc_time)
        call health#report_error('`escape-time` is not set', suggestions)
      elseif tmux_esc_time > 300
        call health#report_error(
            \ '`escape-time` ('.tmux_esc_time.') is higher than 300ms', suggestions)
      else
        call health#report_ok('escape-time: '.tmux_esc_time)
      endif
    endif

    " check focus-events
    let suggestions = ["(tmux 1.9+ only) Set `focus-events` in ~/.tmux.conf:\nset-option -g focus-events on"]
    let tmux_focus_events = s:get_tmux_option('focus-events')
    if tmux_focus_events !=# 'error'
      if empty(tmux_focus_events) || tmux_focus_events !=# 'on'
        call health#report_warn(
            \ "`focus-events` is not enabled. |'autoread'| may not work.", suggestions)
      else
        call health#report_ok('focus-events: '.tmux_focus_events)
      endif
    endif

    " check default-terminal and $TERM
    call health#report_info('$TERM: '.$TERM)
    let cmd = 'tmux show-option -qvg default-terminal'
    let out = system(split(cmd))
    let tmux_default_term = substitute(out, '\v(\s|\r|\n)', '', 'g')
    if empty(tmux_default_term)
      let cmd = 'tmux show-option -qvgs default-terminal'
      let out = system(split(cmd))
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
    let info = system(['tmux', 'show-messages', '-JT'])
    let has_tc = stridx(info, " Tc: (flag) true") != -1
    let has_rgb = stridx(info, " RGB: (flag) true") != -1
    if !has_tc && !has_rgb
      call health#report_warn(
            \ "Neither Tc nor RGB capability set. True colors are disabled. |'termguicolors'| won't work properly.",
            \ ["Put this in your ~/.tmux.conf and replace XXX by your $TERM outside of tmux:\nset-option -sa terminal-overrides ',XXX:RGB'",
            \  "For older tmux versions use this instead:\nset-option -ga terminal-overrides ',XXX:Tc'"])
    endif
  endf

  call s:check_tmux()
  ]=], false)
end

local function check_terminal()
  vim.api.nvim_exec(
    [=[
  func! s:check_terminal() abort
    if !executable('infocmp')
      return
    endif
    call health#report_start('terminal')
    let cmd = 'infocmp -L'
    let out = system(split(cmd))
    let kbs_entry   = matchstr(out, 'key_backspace=[^,[:space:]]*')
    let kdch1_entry = matchstr(out, 'key_dc=[^,[:space:]]*')

    if v:shell_error
          \ && (!has('win32')
          \ || empty(matchstr(out,
          \                   'infocmp: couldn''t open terminfo file .\+'
          \                   ..'\%(conemu\|vtpcon\|win32con\)')))
      call health#report_error('command failed: '.cmd."\n".out)
    else
      call health#report_info(printf('key_backspace (kbs) terminfo entry: `%s`', (empty(kbs_entry) ? '? (not found)' : kbs_entry)))
      call health#report_info(printf('key_dc (kdch1) terminfo entry: `%s`', (empty(kbs_entry) ? '? (not found)' : kdch1_entry)))
    endif
    for env_var in ['XTERM_VERSION', 'VTE_VERSION', 'TERM_PROGRAM', 'COLORTERM', 'SSH_TTY']
      if exists('$'.env_var)
        call health#report_info(printf('$%s="%s"', env_var, eval('$'.env_var)))
      endif
    endfor
  endf

  call s:check_terminal()
  ]=],
    false
  )
end

function M.check()
  check_config()
  check_runtime()
  check_performance()
  check_rplugin_manifest()
  check_terminal()
  check_tmux()
end

return M
