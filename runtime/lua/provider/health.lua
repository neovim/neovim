local M = {}

local start = vim.health.start
local ok = vim.health.ok
local info = vim.health.info
local warn = vim.health.warn
local error = vim.health.error
local iswin = vim.uv.os_uname().sysname == 'Windows_NT'

local shell_error_code = 0
local function shell_error()
  return shell_error_code ~= 0
end

-- Returns true if `cmd` exits with success, else false.
local function cmd_ok(cmd)
  vim.fn.system(cmd)
  return vim.v.shell_error == 0
end

local function executable(exe)
  return vim.fn.executable(exe) == 1
end

local function is_blank(s)
  return s:find('^%s*$') ~= nil
end

local function isdir(path)
  if not path then
    return false
  end
  local stat = vim.uv.fs_stat(path)
  if not stat then
    return false
  end
  return stat.type == 'directory'
end

local function isfile(path)
  if not path then
    return false
  end
  local stat = vim.uv.fs_stat(path)
  if not stat then
    return false
  end
  return stat.type == 'file'
end

-- Handler for s:system() function.
local function system_handler(self, _, data, event)
  if event == 'stderr' then
    if self.add_stderr_to_output then
      self.output = self.output .. vim.fn.join(data, '')
    else
      self.stderr = self.stderr .. vim.fn.join(data, '')
    end
  elseif event == 'stdout' then
    self.output = self.output .. vim.fn.join(data, '')
  elseif event == 'exit' then
    shell_error_code = data
  end
end

-- Attempts to construct a shell command from an args list.
-- Only for display, to help users debug a failed command.
local function shellify(cmd)
  if type(cmd) ~= 'table' then
    return cmd
  end
  return vim.fn.join(
    vim.fn.map(vim.fn.copy(cmd), [[v:val =~# ''\m[^\-.a-zA-Z_/]'' ? shellescape(v:val) : v:val]]),
    ' '
  )
end

-- Run a system command and timeout after 30 seconds.
local function system(cmd, ...)
  local args = { ... }
  local args_count = vim.tbl_count(args)

  local stdin = (args_count > 0 and args[1] or '')
  local stderr = (args_count > 1 and args[2] or false)
  local ignore_error = (args_count > 2 and args[3] or false)

  local opts = {
    add_stderr_to_output = stderr,
    output = '',
    stderr = '',
    on_stdout = system_handler,
    on_stderr = system_handler,
    on_exit = system_handler,
  }
  local jobid = vim.fn.jobstart(cmd, opts)

  if jobid < 1 then
    local message = 'Command error (job='
      .. jobid
      .. '): `'
      .. shellify(cmd)
      .. '` (in '
      .. vim.fn.string(vim.fn.getcwd())
      .. ')'

    error(message)
    shell_error_code = 1
    return opts.output
  end

  if not is_blank(stdin) then
    vim.api.nvim_chan_send(jobid, stdin)
  end

  local res = vim.fn.jobwait({ jobid }, 30000)
  if res[1] == -1 then
    error('Command timed out: ' .. shellify(cmd))
    vim.fn.jobstop(jobid)
  elseif shell_error() and not ignore_error then
    local emsg = 'Command error (job='
      .. jobid
      .. ', exit code '
      .. shell_error_code
      .. '): `'
      .. shellify(cmd)
      .. '` (in '
      .. vim.fn.string(vim.fn.getcwd())
      .. ')'
    if not is_blank(opts.output) then
      emsg = emsg .. '\noutput: ' .. opts.output
    end
    if not is_blank(opts.stderr) then
      emsg = emsg .. '\nstderr: ' .. opts.stderr
    end
    error(emsg)
  end

  -- return opts.output
  local _ = ...
  return vim.trim(vim.fn.system(cmd))
end

local function clipboard()
  start('Clipboard (optional)')

  if
    os.getenv('TMUX')
    and executable('tmux')
    and executable('pbpaste')
    and not cmd_ok('pbpaste')
  then
    local tmux_version = string.match(vim.fn.system('tmux -V'), '%d+%.%d+')
    local advice = {
      'Install tmux 2.6+.  https://superuser.com/q/231130',
      'or use tmux with reattach-to-user-namespace.  https://superuser.com/a/413233',
    }
    error('pbcopy does not work with tmux version: ' .. tmux_version, advice)
  end

  local clipboard_tool = vim.fn['provider#clipboard#Executable']()
  if vim.g.clipboard and is_blank(clipboard_tool) then
    local error_message = vim.fn['provider#clipboard#Error']()
    error(
      error_message,
      "Use the example in :help g:clipboard as a template, or don't set g:clipboard at all."
    )
  elseif is_blank(clipboard_tool) then
    warn(
      'No clipboard tool found. Clipboard registers (`"+` and `"*`) will not work.',
      ':help clipboard'
    )
  else
    ok('Clipboard tool found: ' .. clipboard_tool)
  end
end

local function disabled_via_loaded_var(provider)
  local loaded_var = 'loaded_' .. provider .. '_provider'
  local v = vim.g[loaded_var]
  if v == 0 then
    info('Disabled (' .. loaded_var .. '=' .. v .. ').')
    return true
  end
  return false
end

-- Check if pyenv is available and a valid pyenv root can be found, then return
-- their respective paths. If either of those is invalid, return two empty
-- strings, effectively ignoring pyenv.
local function check_for_pyenv()
  local pyenv_path = vim.fn.resolve(vim.fn.exepath('pyenv'))

  if is_blank(pyenv_path) then
    return { '', '' }
  end

  info('pyenv: Path: ' .. pyenv_path)

  local pyenv_root = os.getenv('PYENV_ROOT') and vim.fn.resolve(os.getenv('PYENV_ROOT')) or ''

  if is_blank(pyenv_root) then
    pyenv_root = vim.trim(system({ pyenv_path, 'root' }))
    info('pyenv: $PYENV_ROOT is not set. Infer from `pyenv root`.')
  end

  if not isdir(pyenv_root) then
    local message = 'pyenv: Root does not exist: '
      .. pyenv_root
      .. '. Ignoring pyenv for all following checks.'
    warn(message)
    return { '', '' }
  end

  info('pyenv: Root: ' .. pyenv_root)

  return { pyenv_path, pyenv_root }
end

-- Check the Python interpreter's usability.
local function check_bin(bin)
  if not isfile(bin) and (not iswin or not isfile(bin .. '.exe')) then
    error('"' .. bin .. '" was not found.')
    return false
  elseif not executable(bin) then
    error('"' .. bin .. '" is not executable.')
    return false
  end
  return true
end

-- Fetch the contents of a URL.
local function download(url)
  local has_curl = executable('curl')
  if has_curl and vim.fn.system({ 'curl', '-V' }):find('Protocols:.*https') then
    local rv = system({ 'curl', '-sL', url }, '', 1, 1)
    if shell_error() then
      return 'curl error with ' .. url .. ': ' .. shell_error_code
    else
      return rv
    end
  elseif executable('python') then
    local script = "try:\n\
          from urllib.request import urlopen\n\
          except ImportError:\n\
          from urllib2 import urlopen\n\
          response = urlopen('" .. url .. "')\n\
          print(response.read().decode('utf8'))\n"
    local rv = system({ 'python', '-c', script })
    if is_blank(rv) and shell_error() then
      return 'python urllib.request error: ' .. shell_error_code
    else
      return rv
    end
  end

  local message = 'missing `curl` '

  if has_curl then
    message = message .. '(with HTTPS support) '
  end
  message = message .. 'and `python`, cannot make web request'

  return message
end

-- Get the latest Nvim Python client (pynvim) version from PyPI.
local function latest_pypi_version()
  local pypi_version = 'unable to get pypi response'
  local pypi_response = download('https://pypi.python.org/pypi/pynvim/json')
  if not is_blank(pypi_response) then
    local pcall_ok, output = pcall(vim.fn.json_decode, pypi_response)
    local pypi_data
    if pcall_ok then
      pypi_data = output
    else
      return 'error: ' .. pypi_response
    end

    local pypi_element = pypi_data['info'] or {}
    pypi_version = pypi_element['version'] or 'unable to parse'
  end
  return pypi_version
end

local function is_bad_response(s)
  local lower = s:lower()
  return vim.startswith(lower, 'unable')
    or vim.startswith(lower, 'error')
    or vim.startswith(lower, 'outdated')
end

-- Get version information using the specified interpreter.  The interpreter is
-- used directly in case breaking changes were introduced since the last time
-- Nvim's Python client was updated.
--
-- Returns: {
--     {python executable version},
--     {current nvim version},
--     {current pypi nvim status},
--     {installed version status}
-- }
local function version_info(python)
  local pypi_version = latest_pypi_version()

  local python_version = vim.trim(system({
    python,
    '-c',
    'import sys; print(".".join(str(x) for x in sys.version_info[:3]))',
  }))

  if is_blank(python_version) then
    python_version = 'unable to parse ' .. python .. ' response'
  end

  local nvim_path = vim.trim(system({
    python,
    '-c',
    'import sys; sys.path = [p for p in sys.path if p != ""]; import neovim; print(neovim.__file__)',
  }))
  if shell_error() or is_blank(nvim_path) then
    return { python_version, 'unable to load neovim Python module', pypi_version, nvim_path }
  end

  -- Assuming that multiple versions of a package are installed, sort them
  -- numerically in descending order.
  local function compare(metapath1, metapath2)
    local a = vim.fn.matchstr(vim.fn.fnamemodify(metapath1, ':p:h:t'), [[[0-9.]\+]])
    local b = vim.fn.matchstr(vim.fn.fnamemodify(metapath2, ':p:h:t'), [[[0-9.]\+]])
    if a == b then
      return 0
    elseif a > b then
      return 1
    else
      return -1
    end
  end

  -- Try to get neovim.VERSION (added in 0.1.11dev).
  local nvim_version = system({
    python,
    '-c',
    'from neovim import VERSION as v; print("{}.{}.{}{}".format(v.major, v.minor, v.patch, v.prerelease))',
  }, '', 1, 1)
  if is_blank(nvim_version) then
    nvim_version = 'unable to find pynvim module version'
    local base = vim.fs.basename(nvim_path, ':h')
    local metas = vim.fn.glob(base .. '-*/METADATA', 1, 1)
    vim.list_extend(metas, vim.fn.glob(base .. '-*/PKG-INFO', 1, 1))
    vim.list_extend(metas, vim.fn.glob(base .. '.egg-info/PKG-INFO', 1, 1))
    metas = table.sort(metas, compare)

    if metas and next(metas) ~= nil then
      for _, meta_line in ipairs(vim.fn.readfile(metas[1])) do
        if vim.startswith(meta_line, 'Version:') then
          nvim_version = vim.fn.matchstr(meta_line, [[^Version: \zs\S\+]])
          break
        end
      end
    end
  end

  local nvim_path_base = vim.fn.fnamemodify(nvim_path, [[:~:h]])
  local version_status = 'unknown; ' .. nvim_path_base
  if is_bad_response(nvim_version) and is_bad_response(pypi_version) then
    if vim.version.lt(nvim_version, pypi_version) then
      version_status = 'outdated; from ' .. nvim_path_base
    else
      version_status = 'up to date'
    end
  end

  return { python_version, nvim_version, pypi_version, version_status }
end

-- Resolves Python executable path by invoking and checking `sys.executable`.
local function python_exepath(invocation)
  return vim.fs.normalize(
    system(vim.fn.fnameescape(invocation) .. ' -c "import sys; sys.stdout.write(sys.executable)"')
  )
end

local function python()
  start('Python 3 provider (optional)')

  local pyname = 'python3'
  local python_exe = ''
  local virtual_env = os.getenv('VIRTUAL_ENV')
  local venv = virtual_env and vim.fn.resolve(virtual_env) or ''
  local host_prog_var = pyname .. '_host_prog'
  local python_multiple = {}

  if disabled_via_loaded_var(pyname) then
    return
  end

  local pyenv_table = check_for_pyenv()
  local pyenv = pyenv_table[1]
  local pyenv_root = pyenv_table[2]

  if vim.g[host_prog_var] then
    local message = 'Using: g:' .. host_prog_var .. ' = "' .. vim.g[host_prog_var] .. '"'
    info(message)
  end

  local python_table = vim.fn['provider#pythonx#Detect'](3)
  pyname = python_table[1]
  local pythonx_warnings = python_table[2]

  if is_blank(pyname) then
    warn(
      'No Python executable found that can `import neovim`. '
        .. 'Using the first available executable for diagnostics.'
    )
  elseif vim.g[host_prog_var] then
    python_exe = pyname
  end

  -- No Python executable could `import neovim`, or host_prog_var was used.
  if not is_blank(pythonx_warnings) then
    warn(pythonx_warnings, {
      'See :help provider-python for more information.',
      'You may disable this provider (and warning) by adding `let g:loaded_python3_provider = 0` to your init.vim',
    })
  elseif not is_blank(pyname) and is_blank(python_exe) then
    if not vim.g[host_prog_var] then
      local message = '`g:'
        .. host_prog_var
        .. '` is not set.  Searching for '
        .. pyname
        .. ' in the environment.'
      info(message)
    end

    if not is_blank(pyenv) then
      python_exe = vim.trim(system({ pyenv, 'which', pyname }, '', 1))
      if is_blank(python_exe) then
        warn('pyenv could not find ' .. pyname .. '.')
      end
    end

    if is_blank(python_exe) then
      python_exe = vim.fn.exepath(pyname)

      if os.getenv('PATH') then
        local path_sep = iswin and ';' or ':'
        local paths = vim.split(os.getenv('PATH') or '', path_sep)

        for _, path in ipairs(paths) do
          local path_bin = vim.fs.normalize(path .. '/' .. pyname)
          if
            path_bin ~= vim.fs.normalize(python_exe)
            and vim.list_contains(python_multiple, path_bin)
            and executable(path_bin)
          then
            python_multiple[#python_multiple + 1] = path_bin
          end
        end

        if vim.tbl_count(python_multiple) > 0 then
          -- This is worth noting since the user may install something
          -- that changes $PATH, like homebrew.
          local message = 'Multiple '
            .. pyname
            .. ' executables found.  '
            .. 'Set `g:'
            .. host_prog_var
            .. '` to avoid surprises.'
          info(message)
        end

        if python_exe:find('shims') then
          local message = '`' .. python_exe .. '` appears to be a pyenv shim.'
          local advice = '`pyenv` is not in $PATH, your pyenv installation is broken. Set `g:'
            .. host_prog_var
            .. '` to avoid surprises.'

          warn(message, advice)
        end
      end
    end
  end

  if not is_blank(python_exe) and not vim.g[host_prog_var] then
    if
      is_blank(venv)
      and not is_blank(pyenv)
      and not is_blank(pyenv_root)
      and vim.startswith(vim.fn.resolve(python_exe), pyenv_root .. '/')
    then
      local advice = 'Create a virtualenv specifically for Nvim using pyenv, and set `g:'
        .. host_prog_var
        .. '`.  This will avoid the need to install the pynvim module in each version/virtualenv.'
      warn('pyenv is not set up optimally.', advice)
    elseif not is_blank(venv) then
      local venv_root
      if not is_blank(pyenv_root) then
        venv_root = pyenv_root
      else
        venv_root = vim.fs.dirname(venv)
      end

      if vim.startswith(vim.fn.resolve(python_exe), venv_root .. '/') then
        local advice = 'Create a virtualenv specifically for Nvim and use `g:'
          .. host_prog_var
          .. '`.  This will avoid the need to install the pynvim module in each virtualenv.'
        warn('Your virtualenv is not set up optimally.', advice)
      end
    end
  end

  if is_blank(python_exe) and not is_blank(pyname) then
    -- An error message should have already printed.
    error('`' .. pyname .. '` was not found.')
  elseif not is_blank(python_exe) and not check_bin(python_exe) then
    python_exe = ''
  end

  -- Diagnostic output
  info('Executable: ' .. (is_blank(python_exe) and 'Not found' or python_exe))
  if vim.tbl_count(python_multiple) > 0 then
    for _, path_bin in ipairs(python_multiple) do
      info('Other python executable: ' .. path_bin)
    end
  end

  if is_blank(python_exe) then
    -- No Python executable can import 'neovim'. Check if any Python executable
    -- can import 'pynvim'. If so, that Python failed to import 'neovim' as
    -- well, which is most probably due to a failed pip upgrade:
    -- https://github.com/neovim/neovim/wiki/Following-HEAD#20181118
    local pynvim_table = vim.fn['provider#pythonx#DetectByModule']('pynvim', 3)
    local pynvim_exe = pynvim_table[1]
    if not is_blank(pynvim_exe) then
      local message = 'Detected pip upgrade failure: Python executable can import "pynvim" but not "neovim": '
        .. pynvim_exe
      local advice = {
        'Use that Python version to reinstall "pynvim" and optionally "neovim".',
        pynvim_exe .. ' -m pip uninstall pynvim neovim',
        pynvim_exe .. ' -m pip install pynvim',
        pynvim_exe .. ' -m pip install neovim  # only if needed by third-party software',
      }
      error(message, advice)
    end
  else
    local version_info_table = version_info(python_exe)
    local majorpyversion = version_info_table[1]
    local current = version_info_table[2]
    local latest = version_info_table[3]
    local status = version_info_table[4]

    if vim.fn.str2nr(majorpyversion) ~= 3 then
      warn('Unexpected Python version. This could lead to confusing error messages.')
    end

    info('Python version: ' .. majorpyversion)

    if is_bad_response(status) then
      info('pynvim version: ' .. current .. ' (' .. status .. ')')
    else
      info('pynvim version: ' .. current)
    end

    if is_bad_response(current) then
      error(
        'pynvim is not installed.\nError: ' .. current,
        'Run in shell: ' .. python_exe .. ' -m pip install pynvim'
      )
    end

    if is_bad_response(latest) then
      warn('Could not contact PyPI to get latest version.')
      error('HTTP request failed: ' .. latest)
    elseif is_bad_response(status) then
      warn('Latest pynvim is NOT installed: ' .. latest)
    elseif not is_bad_response(current) then
      ok('Latest pynvim is installed.')
    end
  end

  start('Python virtualenv')
  if not virtual_env then
    ok('no $VIRTUAL_ENV')
    return
  end
  local errors = {}
  -- Keep hints as dict keys in order to discard duplicates.
  local hints = {}
  -- The virtualenv should contain some Python executables, and those
  -- executables should be first both on Nvim's $PATH and the $PATH of
  -- subshells launched from Nvim.
  local bin_dir = iswin and 'Scripts' or 'bin'
  local venv_bins = vim.tbl_filter(function(v)
    -- XXX: Remove irrelevant executables found in bin/.
    return not v:match('python%-config')
  end, vim.fn.glob(string.format('%s/%s/python*', virtual_env, bin_dir), true, true))
  if vim.tbl_count(venv_bins) > 0 then
    for _, venv_bin in pairs(venv_bins) do
      venv_bin = vim.fs.normalize(venv_bin)
      local py_bin_basename = vim.fs.basename(venv_bin)
      local nvim_py_bin = python_exepath(vim.fn.exepath(py_bin_basename))
      local subshell_py_bin = python_exepath(py_bin_basename)
      if venv_bin ~= nvim_py_bin then
        errors[#errors + 1] = '$PATH yields this '
          .. py_bin_basename
          .. ' executable: '
          .. nvim_py_bin
        local hint = '$PATH ambiguities arise if the virtualenv is not '
          .. 'properly activated prior to launching Nvim. Close Nvim, activate the virtualenv, '
          .. 'check that invoking Python from the command line launches the correct one, '
          .. 'then relaunch Nvim.'
        hints[hint] = true
      end
      if venv_bin ~= subshell_py_bin then
        errors[#errors + 1] = '$PATH in subshells yields this '
          .. py_bin_basename
          .. ' executable: '
          .. subshell_py_bin
        local hint = '$PATH ambiguities in subshells typically are '
          .. 'caused by your shell config overriding the $PATH previously set by the '
          .. 'virtualenv. Either prevent them from doing so, or use this workaround: '
          .. 'https://vi.stackexchange.com/a/34996'
        hints[hint] = true
      end
    end
  else
    errors[#errors + 1] = 'no Python executables found in the virtualenv '
      .. bin_dir
      .. ' directory.'
  end

  local msg = '$VIRTUAL_ENV is set to: ' .. virtual_env
  if vim.tbl_count(errors) > 0 then
    if vim.tbl_count(venv_bins) > 0 then
      msg = msg
        .. '\nAnd its '
        .. bin_dir
        .. ' directory contains: '
        .. vim.fn.join(vim.fn.map(venv_bins, [[fnamemodify(v:val, ':t')]]), ', ')
    end
    local conj = '\nBut '
    for _, err in ipairs(errors) do
      msg = msg .. conj .. err
      conj = '\nAnd '
    end
    msg = msg .. '\nSo invoking Python may lead to unexpected results.'
    warn(msg, vim.fn.keys(hints))
  else
    info(msg)
    info(
      'Python version: '
        .. system('python -c "import platform, sys; sys.stdout.write(platform.python_version())"')
    )
    ok('$VIRTUAL_ENV provides :!python.')
  end
end

local function ruby()
  start('Ruby provider (optional)')

  if disabled_via_loaded_var('ruby') then
    return
  end

  if not executable('ruby') or not executable('gem') then
    warn(
      '`ruby` and `gem` must be in $PATH.',
      'Install Ruby and verify that `ruby` and `gem` commands work.'
    )
    return
  end
  info('Ruby: ' .. system({ 'ruby', '-v' }))

  local ruby_detect_table = vim.fn['provider#ruby#Detect']()
  local host = ruby_detect_table[1]
  if is_blank(host) then
    warn('`neovim-ruby-host` not found.', {
      'Run `gem install neovim` to ensure the neovim RubyGem is installed.',
      'Run `gem environment` to ensure the gem bin directory is in $PATH.',
      'If you are using rvm/rbenv/chruby, try "rehashing".',
      'See :help g:ruby_host_prog for non-standard gem installations.',
      'You may disable this provider (and warning) by adding `let g:loaded_ruby_provider = 0` to your init.vim',
    })
    return
  end
  info('Host: ' .. host)

  local latest_gem_cmd = (iswin and 'cmd /c gem list -ra "^^neovim$"' or 'gem list -ra ^neovim$')
  local latest_gem = system(vim.fn.split(latest_gem_cmd))
  if shell_error() or is_blank(latest_gem) then
    error(
      'Failed to run: ' .. latest_gem_cmd,
      { "Make sure you're connected to the internet.", 'Are you behind a firewall or proxy?' }
    )
    return
  end
  local gem_split = vim.split(latest_gem, [[neovim (\|, \|)$]])
  latest_gem = gem_split[1] or 'not found'

  local current_gem_cmd = { host, '--version' }
  local current_gem = system(current_gem_cmd)
  if shell_error() then
    error(
      'Failed to run: ' .. table.concat(current_gem_cmd, ' '),
      { 'Report this issue with the output of: ', table.concat(current_gem_cmd, ' ') }
    )
    return
  end

  if vim.version.lt(current_gem, latest_gem) then
    local message = 'Gem "neovim" is out-of-date. Installed: '
      .. current_gem
      .. ', latest: '
      .. latest_gem
    warn(message, 'Run in shell: gem update neovim')
  else
    ok('Latest "neovim" gem is installed: ' .. current_gem)
  end
end

local function node()
  start('Node.js provider (optional)')

  if disabled_via_loaded_var('node') then
    return
  end

  if
    not executable('node')
    or (not executable('npm') and not executable('yarn') and not executable('pnpm'))
  then
    warn(
      '`node` and `npm` (or `yarn`, `pnpm`) must be in $PATH.',
      'Install Node.js and verify that `node` and `npm` (or `yarn`, `pnpm`) commands work.'
    )
    return
  end

  -- local node_v = vim.fn.split(system({'node', '-v'}), "\n")[1] or ''
  local node_v = system({ 'node', '-v' })
  info('Node.js: ' .. node_v)
  if shell_error() or vim.version.lt(node_v, '6.0.0') then
    warn('Nvim node.js host does not support Node ' .. node_v)
    -- Skip further checks, they are nonsense if nodejs is too old.
    return
  end
  if vim.fn['provider#node#can_inspect']() == 0 then
    warn(
      'node.js on this system does not support --inspect-brk so $NVIM_NODE_HOST_DEBUG is ignored.'
    )
  end

  local node_detect_table = vim.fn['provider#node#Detect']()
  local host = node_detect_table[1]
  if is_blank(host) then
    warn('Missing "neovim" npm (or yarn, pnpm) package.', {
      'Run in shell: npm install -g neovim',
      'Run in shell (if you use yarn): yarn global add neovim',
      'Run in shell (if you use pnpm): pnpm install -g neovim',
      'You may disable this provider (and warning) by adding `let g:loaded_node_provider = 0` to your init.vim',
    })
    return
  end
  info('Nvim node.js host: ' .. host)

  local manager = 'npm'
  if executable('yarn') then
    manager = 'yarn'
  elseif executable('pnpm') then
    manager = 'pnpm'
  end

  local latest_npm_cmd = (
    iswin and 'cmd /c ' .. manager .. ' info neovim --json' or manager .. ' info neovim --json'
  )
  local latest_npm = system(vim.fn.split(latest_npm_cmd))
  if shell_error() or is_blank(latest_npm) then
    error(
      'Failed to run: ' .. latest_npm_cmd,
      { "Make sure you're connected to the internet.", 'Are you behind a firewall or proxy?' }
    )
    return
  end

  local pcall_ok, output = pcall(vim.fn.json_decode, latest_npm)
  local pkg_data
  if pcall_ok then
    pkg_data = output
  else
    return 'error: ' .. latest_npm
  end
  local latest_npm_subtable = pkg_data['dist-tags'] or {}
  latest_npm = latest_npm_subtable['latest'] or 'unable to parse'

  local current_npm_cmd = { 'node', host, '--version' }
  local current_npm = system(current_npm_cmd)
  if shell_error() then
    error(
      'Failed to run: ' .. table.concat(current_npm_cmd, ' '),
      { 'Report this issue with the output of: ', table.concat(current_npm_cmd, ' ') }
    )
    return
  end

  if latest_npm ~= 'unable to parse' and vim.version.lt(current_npm, latest_npm) then
    local message = 'Package "neovim" is out-of-date. Installed: '
      .. current_npm
      .. ' latest: '
      .. latest_npm
    warn(message({
      'Run in shell: npm install -g neovim',
      'Run in shell (if you use yarn): yarn global add neovim',
      'Run in shell (if you use pnpm): pnpm install -g neovim',
    }))
  else
    ok('Latest "neovim" npm/yarn/pnpm package is installed: ' .. current_npm)
  end
end

local function perl()
  start('Perl provider (optional)')

  if disabled_via_loaded_var('perl') then
    return
  end

  local perl_detect_table = vim.fn['provider#perl#Detect']()
  local perl_exec = perl_detect_table[1]
  local perl_warnings = perl_detect_table[2]

  if is_blank(perl_exec) then
    if not is_blank(perl_warnings) then
      warn(perl_warnings, {
        'See :help provider-perl for more information.',
        'You may disable this provider (and warning) by adding `let g:loaded_perl_provider = 0` to your init.vim',
      })
    else
      warn('No usable perl executable found')
    end
    return
  end

  info('perl executable: ' .. perl_exec)

  -- we cannot use cpanm that is on the path, as it may not be for the perl
  -- set with g:perl_host_prog
  system({ perl_exec, '-W', '-MApp::cpanminus', '-e', '' })
  if shell_error() then
    return { perl_exec, '"App::cpanminus" module is not installed' }
  end

  local latest_cpan_cmd = {
    perl_exec,
    '-MApp::cpanminus::script',
    '-e',
    'my $app = App::cpanminus::script->new; $app->parse_options ("--info", "-q", "Neovim::Ext"); exit $app->doit',
  }

  local latest_cpan = system(latest_cpan_cmd)
  if shell_error() or is_blank(latest_cpan) then
    error(
      'Failed to run: ' .. table.concat(latest_cpan_cmd, ' '),
      { "Make sure you're connected to the internet.", 'Are you behind a firewall or proxy?' }
    )
    return
  elseif latest_cpan[1] == '!' then
    local cpanm_errs = vim.split(latest_cpan, '!')
    if cpanm_errs[1]:find("Can't write to ") then
      local advice = {}
      for i = 2, #cpanm_errs do
        advice[#advice + 1] = cpanm_errs[i]
      end

      warn(cpanm_errs[1], advice)
      -- Last line is the package info
      latest_cpan = cpanm_errs[#cpanm_errs]
    else
      error('Unknown warning from command: ' .. latest_cpan_cmd, cpanm_errs)
      return
    end
  end
  latest_cpan = vim.fn.matchstr(latest_cpan, [[\(\.\?\d\)\+]])
  if is_blank(latest_cpan) then
    error('Cannot parse version number from cpanm output: ' .. latest_cpan)
    return
  end

  local current_cpan_cmd = { perl_exec, '-W', '-MNeovim::Ext', '-e', 'print $Neovim::Ext::VERSION' }
  local current_cpan = system(current_cpan_cmd)
  if shell_error() then
    error(
      'Failed to run: ' .. table.concat(current_cpan_cmd, ' '),
      { 'Report this issue with the output of: ', table.concat(current_cpan_cmd, ' ') }
    )
    return
  end

  if vim.version.lt(current_cpan, latest_cpan) then
    local message = 'Module "Neovim::Ext" is out-of-date. Installed: '
      .. current_cpan
      .. ', latest: '
      .. latest_cpan
    warn(message, 'Run in shell: cpanm -n Neovim::Ext')
  else
    ok('Latest "Neovim::Ext" cpan module is installed: ' .. current_cpan)
  end
end

function M.check()
  clipboard()
  python()
  ruby()
  node()
  perl()
end

return M
