local M = {}

function M.report_start(msg)
  vim.fn['health#report_start'](msg)
end

M.start = M.report_start

function M.report_info(msg)
  vim.fn['health#report_info'](msg)
end

M.info = M.report_info

function M.report_ok(msg)
  vim.fn['health#report_ok'](msg)
end

M.ok = M.report_ok

function M.report_warn(msg, ...)
  vim.fn['health#report_warn'](msg, ...)
end

M.warn = M.report_warn

function M.report_error(msg, ...)
  vim.fn['health#report_error'](msg, ...)
end

M.error = M.report_error

function M.provider_disabled(provider)
  local loaded_var = 'loaded_' .. provider .. '_provider'
  local v = vim.g[loaded_var]
  if v == 0 then
    M.report_info('Disabled (' .. loaded_var .. '=' .. v .. ').')
    return true
  end
  return false
end

-- Handler for s:system() function.
local function system_handler(self, _, data, event)
  if event == 'stderr' then
    if self.add_stderr_to_output then
      self.output = self.output .. table.concat(data, '')
    else
      self.stderr = self.stderr .. table.concat(data, '')
    end
  elseif event == 'stdout' then
    self.output = self.output .. table.concat(data, '')
  end
end

-- Attempts to construct a shell command from an args list.
-- Only for display, to help users debug a failed command.
local function shellify(cmd)
  if type(cmd) ~= 'table' then
    return cmd
  end
  local escaped = {}
  for i, v in ipairs(cmd) do
    if v:match('[^A-Za-z_/.-]') then
      escaped[i] = vim.fn.shellescape(v)
    else
      escaped[i] = v
    end
  end
  return table.concat(escaped, ' ')
end

function M.cmd_ok(cmd)
  local out = vim.fn.system(cmd)
  return vim.v.shell_error == 0, out
end

--- Run a system command and timeout after 30 seconds.
---
--- @param cmd table List of command arguments to execute
--- @param args ?table Optional arguments:
---                   - stdin (string): Data to write to the job's stdin
---                   - stderr (boolean): Append stderr to stdout
---                   - ignore_error (boolean): If true, ignore error output
---                   - timeout (number): Number of seconds to wait before timing out (default 30)
function M.system(cmd, args)
  args = args or {}
  local stdin = args.stdin or ''
  local stderr = vim.F.if_nil(args.stderr, false)
  local ignore_error = vim.F.if_nil(args.ignore_error, false)

  local shell_error_code = 0
  local opts = {
    add_stderr_to_output = stderr,
    output = '',
    stderr = '',
    on_stdout = system_handler,
    on_stderr = system_handler,
    on_exit = function(_, data)
      shell_error_code = data
    end,
  }
  local jobid = vim.fn.jobstart(cmd, opts)

  if jobid < 1 then
    local message =
        string.format('Command error (job=%d): %s (in %s)', jobid, shellify(cmd), vim.loop.cwd())
    error(message)
    return opts.output, 1
  end

  if stdin:find('^%s$') then
    vim.fn.jobsend(jobid, stdin)
  end

  local res = vim.fn.jobwait({ jobid }, vim.F.if_nil(args.timeout, 30) * 1000)
  if res[1] == -1 then
    error('Command timed out: ' .. shellify(cmd))
    vim.fn.jobstop(jobid)
  elseif shell_error_code ~= 0 and not ignore_error then
    local emsg = string.format(
      'Command error (job=%d, exit code %d): %s (in %s)',
      jobid,
      shell_error_code,
      shellify(cmd),
      vim.loop.cwd()
    )
    if opts.output:find('%S') then
      emsg = string.format('%s\noutput: %s', emsg, opts.output)
    end
    if opts.stderr:find('%S') then
      emsg = string.format('%s\nstderr: %s', emsg, opts.stderr)
    end
    error(emsg)
  end

  -- return opts.output
  return vim.trim(vim.fn.system(cmd)), shell_error_code
end

local path2name = function(path)
  if path:match('%.lua$') then
    -- Lua: transform "../lua/vim/lsp/health.lua" into "vim.lsp"

    -- Get full path, make sure all slashes are '/'
    path = vim.fs.normalize(path)

    -- Remove everything up to the last /lua/ folder
    path = path:gsub('^.*/lua/', '')

    -- Remove the filename (health.lua)
    path = vim.fn.fnamemodify(path, ':h')

    -- Change slashes to dots
    path = path:gsub('/', '.')

    return path
  else
    -- Vim: transform "../autoload/health/provider.vim" into "provider"
    return vim.fn.fnamemodify(path, ':t:r')
  end
end

local PATTERNS = { '/autoload/health/*.vim', '/lua/**/**/health.lua', '/lua/**/**/health/init.lua' }
-- :checkhealth completion function used by ex_getln.c get_healthcheck_names()
M._complete = function()
  local names = vim.tbl_flatten(vim.tbl_map(function(pattern)
    return vim.tbl_map(path2name, vim.api.nvim_get_runtime_file(pattern, true))
  end, PATTERNS))
  -- Remove duplicates
  local unique = {}
  vim.tbl_map(function(f)
    unique[f] = true
  end, names)
  -- vim.health is this file, which is not a healthcheck
  unique['vim'] = nil
  return vim.tbl_keys(unique)
end

return M
