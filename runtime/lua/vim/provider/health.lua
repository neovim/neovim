local health = vim.health
local iswin = vim.uv.os_uname().sysname == 'Windows_NT'

local M = {}

local function clipboard()
  health.start('Clipboard (optional)')

  if
    os.getenv('TMUX')
    and vim.fn.executable('tmux') == 1
    and vim.fn.executable('pbpaste') == 1
    and not health._cmd_ok('pbpaste')
  then
    local tmux_version = string.match(vim.fn.system('tmux -V'), '%d+%.%d+')
    local advice = {
      'Install tmux 2.6+.  https://superuser.com/q/231130',
      'or use tmux with reattach-to-user-namespace.  https://superuser.com/a/413233',
    }
    health.error('pbcopy does not work with tmux version: ' .. tmux_version, advice)
  end

  local clipboard_tool = vim.fn['provider#clipboard#Executable']()
  if vim.g.clipboard ~= nil and clipboard_tool == '' then
    local error_message = vim.fn['provider#clipboard#Error']()
    health.error(
      error_message,
      "Use the example in :help g:clipboard as a template, or don't set g:clipboard at all."
    )
  elseif clipboard_tool:find('^%s*$') then
    health.warn(
      'No clipboard tool found. Clipboard registers (`"+` and `"*`) will not work.',
      ':help clipboard'
    )
  else
    health.ok('Clipboard tool found: ' .. clipboard_tool)
  end
end

local function node()
  health.start('Node.js provider (optional)')

  if health._provider_disabled('node') then
    return
  end

  if
    vim.fn.executable('node') == 0
    or (
      vim.fn.executable('npm') == 0
      and vim.fn.executable('yarn') == 0
      and vim.fn.executable('pnpm') == 0
    )
  then
    health.warn(
      '`node` and `npm` (or `yarn`, `pnpm`) must be in $PATH.',
      'Install Node.js and verify that `node` and `npm` (or `yarn`, `pnpm`) commands work.'
    )
    return
  end

  -- local node_v = vim.fn.split(system({'node', '-v'}), "\n")[1] or ''
  local ok, node_v = health._cmd_ok({ 'node', '-v' })
  health.info('Node.js: ' .. node_v)
  if not ok or vim.version.lt(node_v, '6.0.0') then
    health.warn('Nvim node.js host does not support Node ' .. node_v)
    -- Skip further checks, they are nonsense if nodejs is too old.
    return
  end
  if vim.fn['provider#node#can_inspect']() == 0 then
    health.warn(
      'node.js on this system does not support --inspect-brk so $NVIM_NODE_HOST_DEBUG is ignored.'
    )
  end

  local node_detect_table = vim.fn['provider#node#Detect']()
  local host = node_detect_table[1]
  if host:find('^%s*$') then
    health.warn('Missing "neovim" npm (or yarn, pnpm) package.', {
      'Run in shell: npm install -g neovim',
      'Run in shell (if you use yarn): yarn global add neovim',
      'Run in shell (if you use pnpm): pnpm install -g neovim',
      'You may disable this provider (and warning) by adding `let g:loaded_node_provider = 0` to your init.vim',
    })
    return
  end
  health.info('Nvim node.js host: ' .. host)

  local manager = 'npm'
  if vim.fn.executable('yarn') == 1 then
    manager = 'yarn'
  elseif vim.fn.executable('pnpm') == 1 then
    manager = 'pnpm'
  end

  local latest_npm_cmd = (
    iswin and 'cmd /c ' .. manager .. ' info neovim --json' or manager .. ' info neovim --json'
  )
  local latest_npm
  ok, latest_npm = health._cmd_ok(vim.split(latest_npm_cmd, ' '))
  if not ok or latest_npm:find('^%s$') then
    health.error(
      'Failed to run: ' .. latest_npm_cmd,
      { "Make sure you're connected to the internet.", 'Are you behind a firewall or proxy?' }
    )
    return
  end

  local pcall_ok, pkg_data = pcall(vim.json.decode, latest_npm)
  if not pcall_ok then
    return 'error: ' .. latest_npm
  end
  local latest_npm_subtable = pkg_data['dist-tags'] or {}
  latest_npm = latest_npm_subtable['latest'] or 'unable to parse'

  local current_npm_cmd = { 'node', host, '--version' }
  local current_npm
  ok, current_npm = health._cmd_ok(current_npm_cmd)
  if not ok then
    health.error(
      'Failed to run: ' .. table.concat(current_npm_cmd, ' '),
      { 'Report this issue with the output of: ', table.concat(current_npm_cmd, ' ') }
    )
    return
  end

  if latest_npm ~= 'unable to parse' and vim.version.lt(current_npm, latest_npm) then
    local message = 'Package "neovim" is out-of-date. Installed: '
      .. current_npm:gsub('%\n$', '')
      .. ', latest: '
      .. latest_npm:gsub('%\n$', '')

    health.warn(message, {
      'Run in shell: npm install -g neovim',
      'Run in shell (if you use yarn): yarn global add neovim',
      'Run in shell (if you use pnpm): pnpm install -g neovim',
    })
  else
    health.ok('Latest "neovim" npm/yarn/pnpm package is installed: ' .. current_npm)
  end
end

local function perl()
  health.start('Perl provider (optional)')

  if health._provider_disabled('perl') then
    return
  end

  local perl_exec, perl_warnings = vim.provider.perl.detect()

  if not perl_exec then
    health.warn(assert(perl_warnings), {
      'See :help provider-perl for more information.',
      'You may disable this provider (and warning) by adding `let g:loaded_perl_provider = 0` to your init.vim',
    })
    health.warn('No usable perl executable found')
    return
  end

  health.info('perl executable: ' .. perl_exec)

  -- we cannot use cpanm that is on the path, as it may not be for the perl
  -- set with g:perl_host_prog
  local ok = health._cmd_ok({ perl_exec, '-W', '-MApp::cpanminus', '-e', '' })
  if not ok then
    return { perl_exec, '"App::cpanminus" module is not installed' }
  end

  local latest_cpan_cmd = {
    perl_exec,
    '-MApp::cpanminus::fatscript',
    '-e',
    'my $app = App::cpanminus::script->new; $app->parse_options ("--info", "-q", "Neovim::Ext"); exit $app->doit',
  }
  local latest_cpan
  ok, latest_cpan = health._cmd_ok(latest_cpan_cmd)
  if not ok or latest_cpan:find('^%s*$') then
    health.error(
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

      health.warn(cpanm_errs[1], advice)
      -- Last line is the package info
      latest_cpan = cpanm_errs[#cpanm_errs]
    else
      health.error('Unknown warning from command: ' .. latest_cpan_cmd, cpanm_errs)
      return
    end
  end
  latest_cpan = vim.fn.matchstr(latest_cpan, [[\(\.\?\d\)\+]])
  if latest_cpan:find('^%s*$') then
    health.error('Cannot parse version number from cpanm output: ' .. latest_cpan)
    return
  end

  local current_cpan_cmd = { perl_exec, '-W', '-MNeovim::Ext', '-e', 'print $Neovim::Ext::VERSION' }
  local current_cpan
  ok, current_cpan = health._cmd_ok(current_cpan_cmd)
  if not ok then
    health.error(
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
    health.warn(message, 'Run in shell: cpanm -n Neovim::Ext')
  else
    health.ok('Latest "Neovim::Ext" cpan module is installed: ' .. current_cpan)
  end
end

local function is(path, ty)
  if not path then
    return false
  end
  local stat = vim.uv.fs_stat(path)
  if not stat then
    return false
  end
  return stat.type == ty
end

-- Resolves Python executable path by invoking and checking `sys.executable`.
local function python_exepath(invocation)
  local p = vim.system({ invocation, '-c', 'import sys; sys.stdout.write(sys.executable)' }):wait()
  assert(p.code == 0, p.stderr)
  return vim.fs.normalize(vim.trim(p.stdout))
end

-- Check if pyenv is available and a valid pyenv root can be found, then return
-- their respective paths. If either of those is invalid, return two empty
-- strings, effectively ignoring pyenv.
local function check_for_pyenv()
  local pyenv_path = vim.fn.resolve(vim.fn.exepath('pyenv'))

  if pyenv_path == '' then
    return { '', '' }
  end

  health.info('pyenv: Path: ' .. pyenv_path)

  local pyenv_root = vim.fn.resolve(os.getenv('PYENV_ROOT') or '')

  if pyenv_root == '' then
    pyenv_root = vim.fn.system({ pyenv_path, 'root' })
    health.info('pyenv: $PYENV_ROOT is not set. Infer from `pyenv root`.')
  end

  if not is(pyenv_root, 'directory') then
    local message = string.format(
      'pyenv: Root does not exist: %s. Ignoring pyenv for all following checks.',
      pyenv_root
    )
    health.warn(message)
    return { '', '' }
  end

  health.info('pyenv: Root: ' .. pyenv_root)

  return { pyenv_path, pyenv_root }
end

-- Check the Python interpreter's usability.
local function check_bin(bin)
  if not is(bin, 'file') and (not iswin or not is(bin .. '.exe', 'file')) then
    health.error('"' .. bin .. '" was not found.')
    return false
  elseif vim.fn.executable(bin) == 0 then
    health.error('"' .. bin .. '" is not executable.')
    return false
  end
  return true
end

-- Fetch the contents of a URL.
local function download(url)
  local has_curl = vim.fn.executable('curl') == 1
  if has_curl and vim.fn.system({ 'curl', '-V' }):find('Protocols:.*https') then
    local out, rc = health._system({ 'curl', '-sL', url }, { stderr = true, ignore_error = true })
    if rc ~= 0 then
      return 'curl error with ' .. url .. ': ' .. rc
    else
      return out
    end
  elseif vim.fn.executable('python') == 1 then
    local script = "try:\n\
          from urllib.request import urlopen\n\
          except ImportError:\n\
          from urllib2 import urlopen\n\
          response = urlopen('" .. url .. "')\n\
          print(response.read().decode('utf8'))\n"
    local out, rc = health._system({ 'python', '-c', script })
    if out == '' and rc ~= 0 then
      return 'python urllib.request error: ' .. rc
    else
      return out
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
  if pypi_response ~= '' then
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

  local python_version, rc = health._system({
    python,
    '-c',
    'import sys; print(".".join(str(x) for x in sys.version_info[:3]))',
  })

  if rc ~= 0 or python_version == '' then
    python_version = 'unable to parse ' .. python .. ' response'
  end

  local nvim_path
  nvim_path, rc = health._system({
    python,
    '-c',
    'import sys; sys.path = [p for p in sys.path if p != ""]; import neovim; print(neovim.__file__)',
  })
  if rc ~= 0 or nvim_path == '' then
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
  local nvim_version
  nvim_version, rc = health._system({
    python,
    '-c',
    'from neovim import VERSION as v; print("{}.{}.{}{}".format(v.major, v.minor, v.patch, v.prerelease))',
  }, { stderr = true, ignore_error = true })
  if rc ~= 0 or nvim_version == '' then
    nvim_version = 'unable to find pynvim module version'
    local base = vim.fs.basename(nvim_path)
    local metas = vim.fn.glob(base .. '-*/METADATA', 1, 1)
    vim.list_extend(metas, vim.fn.glob(base .. '-*/PKG-INFO', 1, 1))
    vim.list_extend(metas, vim.fn.glob(base .. '.egg-info/PKG-INFO', 1, 1))
    metas = table.sort(metas, compare)

    if metas and next(metas) ~= nil then
      for line in io.lines(metas[1]) do
        local version = line:match('^Version: (%S+)')
        if version then
          nvim_version = version
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
  health.start('Python 3 provider (optional)')

  local pyname = 'python3' ---@type string?
  local python_exe = ''
  local virtual_env = os.getenv('VIRTUAL_ENV')
  local venv = virtual_env and vim.fn.resolve(virtual_env) or ''
  local host_prog_var = pyname .. '_host_prog'
  local python_multiple = {}

  if health._provider_disabled(pyname) then
    return
  end

  local pyenv_table = check_for_pyenv()
  local pyenv = pyenv_table[1]
  local pyenv_root = pyenv_table[2]

  if vim.g[host_prog_var] then
    local message = string.format('Using: g:%s = "%s"', host_prog_var, vim.g[host_prog_var])
    health.info(message)
  end

  local pythonx_warnings
  pyname, pythonx_warnings = vim.provider.python.detect_by_module('neovim')

  if not pyname then
    health.warn(
      'No Python executable found that can `import neovim`. '
        .. 'Using the first available executable for diagnostics.'
    )
  elseif vim.g[host_prog_var] then
    python_exe = pyname
  end

  -- No Python executable could `import neovim`, or host_prog_var was used.
  if pythonx_warnings then
    health.warn(pythonx_warnings, {
      'See :help provider-python for more information.',
      'You may disable this provider (and warning) by adding `let g:loaded_python3_provider = 0` to your init.vim',
    })
  elseif pyname and pyname ~= '' and python_exe == '' then
    if not vim.g[host_prog_var] then
      local message = string.format(
        '`g:%s` is not set. Searching for %s in the environment.',
        host_prog_var,
        pyname
      )
      health.info(message)
    end

    if pyenv ~= '' then
      python_exe = health._system({ pyenv, 'which', pyname }, { stderr = true })
      if python_exe == '' then
        health.warn('pyenv could not find ' .. pyname .. '.')
      end
    end

    if python_exe == '' then
      python_exe = vim.fn.exepath(pyname)

      if os.getenv('PATH') then
        local path_sep = iswin and ';' or ':'
        local paths = vim.split(os.getenv('PATH') or '', path_sep)

        for _, path in ipairs(paths) do
          local path_bin = vim.fs.normalize(path .. '/' .. pyname)
          if
            path_bin ~= vim.fs.normalize(python_exe)
            and vim.tbl_contains(python_multiple, path_bin)
            and vim.fn.executable(path_bin) == 1
          then
            python_multiple[#python_multiple + 1] = path_bin
          end
        end

        if vim.tbl_count(python_multiple) > 0 then
          -- This is worth noting since the user may install something
          -- that changes $PATH, like homebrew.
          local message = string.format(
            'Multiple %s executables found. Set `g:%s` to avoid surprises.',
            pyname,
            host_prog_var
          )
          health.info(message)
        end

        if python_exe:find('shims') then
          local message = string.format('`%s` appears to be a pyenv shim.', python_exe)
          local advice = string.format(
            '`pyenv` is not in $PATH, your pyenv installation is broken. Set `g:%s` to avoid surprises.',
            host_prog_var
          )
          health.warn(message, advice)
        end
      end
    end
  end

  if python_exe ~= '' and not vim.g[host_prog_var] then
    if
      venv == ''
      and pyenv ~= ''
      and pyenv_root ~= ''
      and vim.startswith(vim.fn.resolve(python_exe), pyenv_root .. '/')
    then
      local advice = string.format(
        'Create a virtualenv specifically for Nvim using pyenv, and set `g:%s`.  This will avoid the need to install the pynvim module in each version/virtualenv.',
        host_prog_var
      )
      health.warn('pyenv is not set up optimally.', advice)
    elseif venv ~= '' then
      local venv_root
      if pyenv_root ~= '' then
        venv_root = pyenv_root
      else
        venv_root = vim.fs.dirname(venv)
      end

      if vim.startswith(vim.fn.resolve(python_exe), venv_root .. '/') then
        local advice = string.format(
          'Create a virtualenv specifically for Nvim and use `g:%s`.  This will avoid the need to install the pynvim module in each virtualenv.',
          host_prog_var
        )
        health.warn('Your virtualenv is not set up optimally.', advice)
      end
    end
  end

  if pyname and python_exe == '' and pyname ~= '' then
    -- An error message should have already printed.
    health.error('`' .. pyname .. '` was not found.')
  elseif python_exe ~= '' and not check_bin(python_exe) then
    python_exe = ''
  end

  -- Diagnostic output
  health.info('Executable: ' .. (python_exe == '' and 'Not found' or python_exe))
  if vim.tbl_count(python_multiple) > 0 then
    for _, path_bin in ipairs(python_multiple) do
      health.info('Other python executable: ' .. path_bin)
    end
  end

  if python_exe == '' then
    -- No Python executable can import 'neovim'. Check if any Python executable
    -- can import 'pynvim'. If so, that Python failed to import 'neovim' as
    -- well, which is most probably due to a failed pip upgrade:
    -- https://github.com/neovim/neovim/wiki/Following-HEAD#20181118
    local pynvim_exe = vim.provider.python.detect_by_module('pynvim')
    if pynvim_exe then
      local message = 'Detected pip upgrade failure: Python executable can import "pynvim" but not "neovim": '
        .. pynvim_exe
      local advice = {
        'Use that Python version to reinstall "pynvim" and optionally "neovim".',
        pynvim_exe .. ' -m pip uninstall pynvim neovim',
        pynvim_exe .. ' -m pip install pynvim',
        pynvim_exe .. ' -m pip install neovim  # only if needed by third-party software',
      }
      health.error(message, advice)
    end
  else
    local version_info_table = version_info(python_exe)
    local pyversion = version_info_table[1]
    local current = version_info_table[2]
    local latest = version_info_table[3]
    local status = version_info_table[4]

    if not vim.version.range('~3'):has(pyversion) then
      health.warn('Unexpected Python version. This could lead to confusing error messages.')
    end

    health.info('Python version: ' .. pyversion)

    if is_bad_response(status) then
      health.info('pynvim version: ' .. current .. ' (' .. status .. ')')
    else
      health.info('pynvim version: ' .. current)
    end

    if is_bad_response(current) then
      health.error(
        'pynvim is not installed.\nError: ' .. current,
        'Run in shell: ' .. python_exe .. ' -m pip install pynvim'
      )
    end

    if is_bad_response(latest) then
      health.warn('Could not contact PyPI to get latest version.')
      health.error('HTTP request failed: ' .. latest)
    elseif is_bad_response(status) then
      health.warn('Latest pynvim is NOT installed: ' .. latest)
    elseif not is_bad_response(current) then
      health.ok('Latest pynvim is installed.')
    end
  end

  health.start('Python virtualenv')
  if not virtual_env then
    health.ok('no $VIRTUAL_ENV')
    return
  end
  local errors = {}
  -- Keep hints as dict keys in order to discard duplicates.
  local hints = {}
  -- The virtualenv should contain some Python executables, and those
  -- executables should be first both on Nvim's $PATH and the $PATH of
  -- subshells launched from Nvim.
  local bin_dir = iswin and 'Scripts' or 'bin'
  local venv_bins = vim.fn.glob(string.format('%s/%s/python*', virtual_env, bin_dir), true, true)
  venv_bins = vim.tbl_filter(function(v)
    -- XXX: Remove irrelevant executables found in bin/.
    return not v:match('python%-config')
  end, venv_bins)
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
      msg = string.format(
        '%s\nAnd its %s directory contains: %s',
        msg,
        bin_dir,
        table.concat(
          vim.tbl_map(function(v)
            return vim.fs.basename(v)
          end, venv_bins),
          ', '
        )
      )
    end
    local conj = '\nBut '
    for _, err in ipairs(errors) do
      msg = msg .. conj .. err
      conj = '\nAnd '
    end
    msg = msg .. '\nSo invoking Python may lead to unexpected results.'
    health.warn(msg, vim.tbl_keys(hints))
  else
    health.info(msg)
    health.info(
      'Python version: '
        .. health._system(
          'python -c "import platform, sys; sys.stdout.write(platform.python_version())"'
        )
    )
    health.ok('$VIRTUAL_ENV provides :!python.')
  end
end

local function ruby()
  health.start('Ruby provider (optional)')

  if health._provider_disabled('ruby') then
    return
  end

  if vim.fn.executable('ruby') == 0 or vim.fn.executable('gem') == 0 then
    health.warn(
      '`ruby` and `gem` must be in $PATH.',
      'Install Ruby and verify that `ruby` and `gem` commands work.'
    )
    return
  end
  health.info('Ruby: ' .. health._system({ 'ruby', '-v' }))

  local host, _ = vim.provider.ruby.detect()
  if (not host) or host:find('^%s*$') then
    health.warn('`neovim-ruby-host` not found.', {
      'Run `gem install neovim` to ensure the neovim RubyGem is installed.',
      'Run `gem environment` to ensure the gem bin directory is in $PATH.',
      'If you are using rvm/rbenv/chruby, try "rehashing".',
      'See :help g:ruby_host_prog for non-standard gem installations.',
      'You may disable this provider (and warning) by adding `let g:loaded_ruby_provider = 0` to your init.vim',
    })
    return
  end
  health.info('Host: ' .. host)

  local latest_gem_cmd = (iswin and 'cmd /c gem list -ra "^^neovim$"' or 'gem list -ra ^neovim$')
  local ok, latest_gem = health._cmd_ok(vim.split(latest_gem_cmd, ' '))
  if not ok or latest_gem:find('^%s*$') then
    health.error(
      'Failed to run: ' .. latest_gem_cmd,
      { "Make sure you're connected to the internet.", 'Are you behind a firewall or proxy?' }
    )
    return
  end
  local gem_split = vim.split(latest_gem, [[neovim (\|, \|)$]])
  latest_gem = gem_split[1] or 'not found'

  local current_gem_cmd = { host, '--version' }
  local current_gem
  ok, current_gem = health._cmd_ok(current_gem_cmd)
  if not ok then
    health.error(
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
    health.warn(message, 'Run in shell: gem update neovim')
  else
    health.ok('Latest "neovim" gem is installed: ' .. current_gem)
  end
end

function M.check()
  clipboard()
  node()
  perl()
  python()
  ruby()
end

return M
