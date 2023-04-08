local M = {}

local start = vim.health.report_start
local ok = vim.health.report_ok
local info = vim.health.report_info
local warn = vim.health.report_warn
local error = vim.health.report_error
local iswin = vim.loop.os_uname().sysname == 'Windows_NT'

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
  local stat = vim.loop.fs_stat(path)
  if not stat then
    return false
  end
  return stat.type == 'directory'
end

local function isfile(path)
  if not path then
    return false
  end
  local stat = vim.loop.fs_stat(path)
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
    vim.cmd([[call jobsend(jobid, stdin)]])
  end

  local res = vim.fn.jobwait({ jobid }, 30000)
  if res[1] == -1 then
    error('Command timed out: ' .. shellify(cmd))
    vim.cmd([[call jobstop(jobid)]])
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
  return vim.fn.system(cmd)
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

  local pyenv_root = os.getenv('PYENV_ROOT') and vim.fn.resolve('$PYENV_ROOT') or ''

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

  if vim.g['host_prog_var'] then
    local message = 'Using: g:' .. host_prog_var .. ' = "' .. vim.g['host_prog_var'] .. '"'
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
  elseif vim.g['host_prog_var'] then
    python_exe = pyname
  end

  -- No Python executable could `import neovim`, or host_prog_var was used.
  if not is_blank(pythonx_warnings) then
    warn(pythonx_warnings, {
      'See :help provider-python for more information.',
      'You may disable this provider (and warning) by adding `let g:loaded_python3_provider = 0` to your init.vim',
    })
  elseif not is_blank(pyname) and is_blank(python_exe) then
    if not vim.g['host_prog_var'] then
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
            and vim.tbl_contains(python_multiple, path_bin)
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
        venv_root = vim.fs.basename(venv)
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
end

function M.check()
  clipboard()
  python()
end

return M
