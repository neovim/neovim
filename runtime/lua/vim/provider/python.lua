local M = {}
local min_version = '3.9'
local s_err ---@type string?
local s_host ---@type string?

local python_candidates = {
  'python3',
  'python3.13',
  'python3.12',
  'python3.11',
  'python3.10',
  'python3.9',
  'python',
}

--- @param prog string
--- @param module string
--- @return integer, string
local function import_module(prog, module)
  local program = [[
import sys, importlib.util;
sys.path = [p for p in sys.path if p != ""];
sys.stdout.write(str(sys.version_info[0]) + "." + str(sys.version_info[1]));]]

  program = program
    .. string.format('sys.exit(2 * int(importlib.util.find_spec("%s") is None))', module)

  local out = vim.system({ prog, '-W', 'ignore', '-c', program }):wait()
  return out.code, assert(out.stdout)
end

--- @param prog string
--- @param module string
--- @return string?
local function check_for_module(prog, module)
  local prog_path = vim.fn.exepath(prog)
  if prog_path == '' then
    return prog .. ' not found in search path or not executable.'
  end

  --   Try to load module, and output Python version.
  --   Exit codes:
  --     0  module can be loaded.
  --     2  module cannot be loaded.
  --     Otherwise something else went wrong (e.g. 1 or 127).
  local prog_exitcode, prog_version = import_module(prog, module)
  if prog_exitcode == 2 or prog_exitcode == 0 then
    -- Check version only for expected return codes.
    if vim.version.lt(prog_version, min_version) then
      return string.format(
        '%s is Python %s and cannot provide Python >= %s.',
        prog_path,
        prog_version,
        min_version
      )
    end
  end

  if prog_exitcode == 2 then
    return string.format('%s does not have the "%s" module.', prog_path, module)
  elseif prog_exitcode == 127 then
    -- This can happen with pyenv's shims.
    return string.format('%s does not exist: %s', prog_path, prog_version)
  elseif prog_exitcode ~= 0 then
    return string.format(
      'Checking %s caused an unknown error. (%s, output: %s) Report this at https://github.com/neovim/neovim',
      prog_path,
      prog_exitcode,
      prog_version
    )
  end

  return nil
end

--- @param module string
--- @return string? path to detected python, if any; nil if not found
--- @return string? error message if python can't be detected by {module}; nil if success
function M.detect_by_module(module)
  local python_exe = vim.fn.expand(vim.g.python3_host_prog or '', true)

  if python_exe ~= '' then
    return vim.fn.exepath(vim.fn.expand(python_exe, true)), nil
  end

  local errors = {}
  for _, exe in ipairs(python_candidates) do
    local error = check_for_module(exe, module)
    if not error then
      return exe, error
    end
    -- Accumulate errors in case we don't find any suitable Python executable.
    table.insert(errors, error)
  end

  -- No suitable Python executable found.
  return nil, 'Could not load Python :\n' .. table.concat(errors, '\n')
end

function M.require(host)
  -- Python host arguments
  local prog = M.detect_by_module('neovim')
  local args = {
    prog,
    '-c',
    'import sys; sys.path = [p for p in sys.path if p != ""]; import neovim; neovim.start_host()',
  }

  -- Collect registered Python plugins into args
  local python_plugins = vim.fn['remote#host#PluginsForHost'](host.name) ---@type any
  ---@param plugin any
  for _, plugin in ipairs(python_plugins) do
    table.insert(args, plugin.path)
  end

  return vim.fn['provider#Poll'](
    args,
    host.orig_name,
    '$NVIM_PYTHON_LOG_FILE',
    { ['overlapped'] = true }
  )
end

function M.call(method, args)
  if s_err then
    return
  end

  if not s_host then
    -- Ensure that we can load the Python3 host before bootstrapping
    local ok, result = pcall(vim.fn['remote#host#Require'], 'legacy-python3-provider') ---@type any, any
    if not ok then
      s_err = result
      vim.api.nvim_echo({ { result, 'WarningMsg' } }, true, {})
      return
    end
    s_host = result
  end

  return vim.fn.rpcrequest(s_host, 'python_' .. method, unpack(args))
end

function M.start()
  -- The Python3 provider plugin will run in a separate instance of the Python3 host.
  vim.fn['remote#host#RegisterClone']('legacy-python3-provider', 'python3')
  vim.fn['remote#host#RegisterPlugin']('legacy-python3-provider', 'script_host.py', {})
end

return M
