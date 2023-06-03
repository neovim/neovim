local M = {}
local health = require('vim.health')

local fn_bool = function(key)
  return function(...)
    return vim.fn[key](...) == 1
  end
end

local has = fn_bool('has')
local executable = fn_bool('executable')
local empty = fn_bool('empty')
local filereadable = fn_bool('filereadable')
local filewritable = fn_bool('filewritable')

local shell_error = function()
  return vim.v.shell_error ~= 0
end

local suggest_faq = 'https://github.com/neovim/neovim/wiki/Building-Neovim#optimized-builds'

local function check_runtime()
  health.start('Runtime')
  -- Files from an old installation.
  local bad_files = {
    ['plugin/man.vim'] = false,
    ['scripts.vim'] = false,
    ['autoload/man.vim'] = false,
  }
  local bad_files_msg = ''
  for k, _ in pairs(bad_files) do
    local path = ('%s/%s'):format(vim.env.VIMRUNTIME, k)
    if vim.uv.fs_stat(path) then
      bad_files[k] = true
      bad_files_msg = ('%s%s\n'):format(bad_files_msg, path)
    end
  end

  local ok = (bad_files_msg == '')
  local info = ok and health.ok or health.info
  info(string.format('$VIMRUNTIME: %s', vim.env.VIMRUNTIME))
  if not ok then
    health.error(
      string.format(
        '$VIMRUNTIME has files from an old installation (this can cause weird behavior):\n%s',
        bad_files_msg
      ),
      { 'Delete $VIMRUNTIME (or uninstall Nvim), then reinstall Nvim.' }
    )
  end
end

local function check_config()
  health.start('Configuration')
  local ok = true

  local vimrc = (
    empty(vim.env.MYVIMRC) and vim.fn.stdpath('config') .. '/init.vim' or vim.env.MYVIMRC
  )
  if not filereadable(vimrc) then
    ok = false
    local has_vim = filereadable(vim.fn.expand('~/.vimrc'))
    health.warn(
      (-1 == vim.fn.getfsize(vimrc) and 'Missing' or 'Unreadable') .. ' user config file: ' .. vimrc,
      { has_vim and ':help nvim-from-vim' or ':help init.vim' }
    )
  end

  -- If $VIM is empty we don't care. Else make sure it is valid.
  if not empty(vim.env.VIM) and not filereadable(vim.env.VIM .. '/runtime/doc/nvim.txt') then
    ok = false
    health.error('$VIM is invalid: ' .. vim.env.VIM)
  end

  if vim.env.NVIM_TUI_ENABLE_CURSOR_SHAPE then
    ok = false
    health.warn('$NVIM_TUI_ENABLE_CURSOR_SHAPE is ignored in Nvim 0.2+', {
      "Use the 'guicursor' option to configure cursor shape. :help 'guicursor'",
      'https://github.com/neovim/neovim/wiki/Following-HEAD#20170402',
    })
  end

  if vim.v.ctype == 'C' then
    ok = false
    health.error(
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
    health.error(
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
    health.error(
      'shada file is not '
        .. ((not writeable or filereadable(shadafile)) and 'writeable' or 'readable')
        .. ':\n'
        .. shadafile
    )
  end

  if ok then
    health.ok('no issues found')
  end
end

local function check_performance()
  health.start('Performance')

  -- Check buildtype
  local buildtype = vim.fn.matchstr(vim.fn.execute('version'), [[\v\cbuild type:?\s*[^\n\r\t ]+]])
  if empty(buildtype) then
    health.error('failed to get build type from :version')
  elseif vim.regex([[\v(MinSizeRel|Release|RelWithDebInfo)]]):match_str(buildtype) then
    health.ok(buildtype)
  else
    health.info(buildtype)
    health.warn('Non-optimized debug build. Nvim will be slower.', {
      'Install a different Nvim package, or rebuild with `CMAKE_BUILD_TYPE=RelWithDebInfo`.',
      suggest_faq,
    })
  end

  -- check for slow shell invocation
  local slow_cmd_time = 1.5
  local start_time = vim.fn.reltime()
  vim.fn.system('echo')
  local elapsed_time = vim.fn.reltimefloat(vim.fn.reltime(start_time))
  if elapsed_time > slow_cmd_time then
    health.warn(
      'Slow shell invocation (took ' .. vim.fn.printf('%.2f', elapsed_time) .. ' seconds).'
    )
  end
end

-- Load the remote plugin manifest file and check for unregistered plugins
local function check_rplugin_manifest()
  health.start('Remote Plugins')

  local existing_rplugins = {}
  for _, item in ipairs(vim.fn['remote#host#PluginsForHost']('python')) do
    existing_rplugins[item.path] = 'python'
  end

  for _, item in ipairs(vim.fn['remote#host#PluginsForHost']('python3')) do
    existing_rplugins[item.path] = 'python3'
  end

  local require_update = false
  local handle_path = function(path)
    local python_glob = vim.fn.glob(path .. '/rplugin/python*', true, true)
    if empty(python_glob) then
      return
    end

    local python_dir = python_glob[1]
    local python_version = vim.fn.fnamemodify(python_dir, ':t')

    local scripts = vim.fn.glob(python_dir .. '/*.py', true, true)
    vim.list_extend(scripts, vim.fn.glob(python_dir .. '/*/__init__.py', true, true))

    for _, script in ipairs(scripts) do
      local contents = vim.fn.join(vim.fn.readfile(script))
      if vim.regex([[\<\%(from\|import\)\s\+neovim\>]]):match_str(contents) then
        if vim.regex([[[\/]__init__\.py$]]):match_str(script) then
          script = vim.fn.tr(vim.fn.fnamemodify(script, ':h'), '\\', '/')
        end
        if not existing_rplugins[script] then
          local msg = vim.fn.printf('"%s" is not registered.', vim.fn.fnamemodify(path, ':t'))
          if python_version == 'pythonx' then
            if not has('python3') then
              msg = msg .. ' (python3 not available)'
            end
          elseif not has(python_version) then
            msg = msg .. vim.fn.printf(' (%s not available)', python_version)
          else
            require_update = true
          end

          health.warn(msg)
        end

        break
      end
    end
  end

  for _, path in ipairs(vim.fn.map(vim.fn.split(vim.o.runtimepath, ','), 'resolve(v:val)')) do
    handle_path(path)
  end

  if require_update then
    health.warn('Out of date', { 'Run `:UpdateRemotePlugins`' })
  else
    health.ok('Up to date')
  end
end

local function check_tmux()
  if empty(vim.env.TMUX) or not executable('tmux') then
    return
  end

  local get_tmux_option = function(option)
    local cmd = 'tmux show-option -qvg ' .. option -- try global scope
    local out = vim.fn.system(vim.fn.split(cmd))
    local val = vim.fn.substitute(out, [[\v(\s|\r|\n)]], '', 'g')
    if shell_error() then
      health.error('command failed: ' .. cmd .. '\n' .. out)
      return 'error'
    elseif empty(val) then
      cmd = 'tmux show-option -qvgs ' .. option -- try session scope
      out = vim.fn.system(vim.fn.split(cmd))
      val = vim.fn.substitute(out, [[\v(\s|\r|\n)]], '', 'g')
      if shell_error() then
        health.error('command failed: ' .. cmd .. '\n' .. out)
        return 'error'
      end
    end
    return val
  end

  health.start('tmux')

  -- check escape-time
  local suggestions =
    { 'set escape-time in ~/.tmux.conf:\nset-option -sg escape-time 10', suggest_faq }
  local tmux_esc_time = get_tmux_option('escape-time')
  if tmux_esc_time ~= 'error' then
    if empty(tmux_esc_time) then
      health.error('`escape-time` is not set', suggestions)
    elseif tonumber(tmux_esc_time) > 300 then
      health.error('`escape-time` (' .. tmux_esc_time .. ') is higher than 300ms', suggestions)
    else
      health.ok('escape-time: ' .. tmux_esc_time)
    end
  end

  -- check focus-events
  local tmux_focus_events = get_tmux_option('focus-events')
  if tmux_focus_events ~= 'error' then
    if empty(tmux_focus_events) or tmux_focus_events ~= 'on' then
      health.warn(
        "`focus-events` is not enabled. |'autoread'| may not work.",
        { '(tmux 1.9+ only) Set `focus-events` in ~/.tmux.conf:\nset-option -g focus-events on' }
      )
    else
      health.ok('focus-events: ' .. tmux_focus_events)
    end
  end

  -- check default-terminal and $TERM
  health.info('$TERM: ' .. vim.env.TERM)
  local cmd = 'tmux show-option -qvg default-terminal'
  local out = vim.fn.system(vim.fn.split(cmd))
  local tmux_default_term = vim.fn.substitute(out, [[\v(\s|\r|\n)]], '', 'g')
  if empty(tmux_default_term) then
    cmd = 'tmux show-option -qvgs default-terminal'
    out = vim.fn.system(vim.fn.split(cmd))
    tmux_default_term = vim.fn.substitute(out, [[\v(\s|\r|\n)]], '', 'g')
  end

  if shell_error() then
    health.error('command failed: ' .. cmd .. '\n' .. out)
  elseif tmux_default_term ~= vim.env.TERM then
    health.info('default-terminal: ' .. tmux_default_term)
    health.error(
      '$TERM differs from the tmux `default-terminal` setting. Colors might look wrong.',
      { '$TERM may have been set by some rc (.bashrc, .zshrc, ...).' }
    )
  elseif not vim.regex([[\v(tmux-256color|screen-256color)]]):match_str(vim.env.TERM) then
    health.error(
      '$TERM should be "screen-256color" or "tmux-256color" in tmux. Colors might look wrong.',
      {
        'Set default-terminal in ~/.tmux.conf:\nset-option -g default-terminal "screen-256color"',
        suggest_faq,
      }
    )
  end

  -- check for RGB capabilities
  local info = vim.fn.system({ 'tmux', 'display-message', '-p', '#{client_termfeatures}' })
  info = vim.split(vim.trim(info), ',', { trimempty = true })
  if not vim.list_contains(info, 'RGB') then
    local has_rgb = false
    if #info == 0 then
      -- client_termfeatures may not be supported; fallback to checking show-messages
      info = vim.fn.system({ 'tmux', 'show-messages', '-JT' })
      has_rgb = info:find(' Tc: (flag) true', 1, true) or info:find(' RGB: (flag) true', 1, true)
    end
    if not has_rgb then
      health.warn(
        "Neither Tc nor RGB capability set. True colors are disabled. |'termguicolors'| won't work properly.",
        {
          "Put this in your ~/.tmux.conf and replace XXX by your $TERM outside of tmux:\nset-option -sa terminal-features ',XXX:RGB'",
          "For older tmux versions use this instead:\nset-option -ga terminal-overrides ',XXX:Tc'",
        }
      )
    end
  end
end

local function check_terminal()
  if not executable('infocmp') then
    return
  end

  health.start('terminal')
  local cmd = 'infocmp -L'
  local out = vim.fn.system(vim.fn.split(cmd))
  local kbs_entry = vim.fn.matchstr(out, 'key_backspace=[^,[:space:]]*')
  local kdch1_entry = vim.fn.matchstr(out, 'key_dc=[^,[:space:]]*')

  if
    shell_error()
    and (
      not has('win32')
      or empty(
        vim.fn.matchstr(
          out,
          [[infocmp: couldn't open terminfo file .\+\%(conemu\|vtpcon\|win32con\)]]
        )
      )
    )
  then
    health.error('command failed: ' .. cmd .. '\n' .. out)
  else
    health.info(
      vim.fn.printf(
        'key_backspace (kbs) terminfo entry: `%s`',
        (empty(kbs_entry) and '? (not found)' or kbs_entry)
      )
    )

    health.info(
      vim.fn.printf(
        'key_dc (kdch1) terminfo entry: `%s`',
        (empty(kbs_entry) and '? (not found)' or kdch1_entry)
      )
    )
  end

  for _, env_var in ipairs({
    'XTERM_VERSION',
    'VTE_VERSION',
    'TERM_PROGRAM',
    'COLORTERM',
    'SSH_TTY',
  }) do
    if vim.env[env_var] then
      health.info(vim.fn.printf('$%s="%s"', env_var, vim.env[env_var]))
    end
  end
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
