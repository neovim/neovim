local M = {}

local s_output = {} ---@type string[]

-- From a path return a list [{name}, {func}, {type}] representing a healthcheck
local function filepath_to_healthcheck(path)
  path = vim.fs.normalize(path)
  local name --- @type string
  local func --- @type string
  local filetype --- @type string
  if path:find('vim$') then
    name = vim.fs.basename(path):gsub('%.vim$', '')
    func = 'health#' .. name .. '#check'
    filetype = 'v'
  else
    local subpath = path:gsub('.*lua/', '')
    if vim.fs.basename(subpath) == 'health.lua' then
      -- */health.lua
      name = assert(vim.fs.dirname(subpath))
    else
      -- */health/init.lua
      name = assert(vim.fs.dirname(assert(vim.fs.dirname(subpath))))
    end
    name = name:gsub('/', '.')

    func = 'require("' .. name .. '.health").check()'
    filetype = 'l'
  end
  return { name, func, filetype }
end

--- @param plugin_names string
--- @return table<any,string[]> { {name, func, type}, ... } representing healthchecks
local function get_healthcheck_list(plugin_names)
  local healthchecks = {} --- @type table<any,string[]>
  local plugin_names_list = vim.split(plugin_names, ' ')
  for _, p in pairs(plugin_names_list) do
    -- support vim/lsp/health{/init/}.lua as :checkhealth vim.lsp

    p = p:gsub('%.', '/')
    p = p:gsub('*', '**')

    local paths = vim.api.nvim_get_runtime_file('autoload/health/' .. p .. '.vim', true)
    vim.list_extend(
      paths,
      vim.api.nvim_get_runtime_file('lua/**/' .. p .. '/health/init.lua', true)
    )
    vim.list_extend(paths, vim.api.nvim_get_runtime_file('lua/**/' .. p .. '/health.lua', true))

    if vim.tbl_count(paths) == 0 then
      healthchecks[#healthchecks + 1] = { p, '', '' } -- healthcheck not found
    else
      local unique_paths = {} --- @type table<string, boolean>
      for _, v in pairs(paths) do
        unique_paths[v] = true
      end
      paths = {}
      for k, _ in pairs(unique_paths) do
        paths[#paths + 1] = k
      end

      for _, v in ipairs(paths) do
        healthchecks[#healthchecks + 1] = filepath_to_healthcheck(v)
      end
    end
  end
  return healthchecks
end

--- @param plugin_names string
--- @return table<string, string[]> {name: [func, type], ..} representing healthchecks
local function get_healthcheck(plugin_names)
  local health_list = get_healthcheck_list(plugin_names)
  local healthchecks = {} --- @type table<string, string[]>
  for _, c in pairs(health_list) do
    if c[1] ~= 'vim' then
      healthchecks[c[1]] = { c[2], c[3] }
    end
  end

  return healthchecks
end

--- Indents lines *except* line 1 of a string if it contains newlines.
---
--- @param s string
--- @param columns integer
--- @return string
local function indent_after_line1(s, columns)
  local lines = vim.split(s, '\n')
  local indent = string.rep(' ', columns)
  for i = 2, #lines do
    lines[i] = indent .. lines[i]
  end
  return table.concat(lines, '\n')
end

--- Changes ':h clipboard' to ':help |clipboard|'.
---
--- @param s string
--- @return string
local function help_to_link(s)
  return vim.fn.substitute(s, [[\v:h%[elp] ([^|][^"\r\n ]+)]], [[:help |\1|]], [[g]])
end

--- Format a message for a specific report item.
---
--- @param status string
--- @param msg string
--- @param ... string|string[] Optional advice
--- @return string
local function format_report_message(status, msg, ...)
  local output = '- ' .. status
  if status ~= '' then
    output = output .. ' '
  end

  output = output .. indent_after_line1(msg, 2)

  local varargs = ...

  -- Optional parameters
  if varargs then
    if type(varargs) == 'string' then
      varargs = { varargs }
    end

    output = output .. '\n  - ADVICE:'

    -- Report each suggestion
    for _, v in ipairs(varargs) do
      if v then
        output = output .. '\n    - ' .. indent_after_line1(v, 6)
      end
    end
  end

  return help_to_link(output)
end

--- @param output string
local function collect_output(output)
  vim.list_extend(s_output, vim.split(output, '\n'))
end

--- Starts a new report.
---
--- @param name string
function M.start(name)
  local input = string.format('\n%s ~', name)
  collect_output(input)
end

--- Reports a message in the current section.
---
--- @param msg string
function M.info(msg)
  local input = format_report_message('', msg)
  collect_output(input)
end

--- Reports a successful healthcheck.
---
--- @param msg string
function M.ok(msg)
  local input = format_report_message('OK', msg)
  collect_output(input)
end

--- Reports a health warning.
---
--- @param msg string
--- @param ... string|string[] Optional advice
function M.warn(msg, ...)
  local input = format_report_message('WARNING', msg, ...)
  collect_output(input)
end

--- Reports a failed healthcheck.
---
--- @param msg string
--- @param ... string|string[] Optional advice
function M.error(msg, ...)
  local input = format_report_message('ERROR', msg, ...)
  collect_output(input)
end

function M.provider_disabled(provider)
  local loaded_var = 'loaded_' .. provider .. '_provider'
  local v = vim.g[loaded_var]
  if v == 0 then
    M.info('Disabled (' .. loaded_var .. '=' .. v .. ').')
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
--- @param args? table Optional arguments:
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
    vim.fn.chansend(jobid, stdin)
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
    path = vim.fs.dirname(path)

    -- Change slashes to dots
    path = path:gsub('/', '.')

    return path
  else
    -- Vim: transform "../autoload/health/provider.vim" into "provider"
    return vim.fn.fnamemodify(path, ':t:r')
  end
end

local PATTERNS = { '/autoload/health/*.vim', '/lua/**/**/health.lua', '/lua/**/**/health/init.lua' }
--- :checkhealth completion function used by cmdexpand.c get_healthcheck_names()
M._complete = function()
  local unique = vim
    .iter(vim.tbl_map(function(pattern)
      return vim.tbl_map(path2name, vim.api.nvim_get_runtime_file(pattern, true))
    end, PATTERNS))
    :flatten()
    :fold({}, function(t, name)
      t[name] = true -- Remove duplicates
      return t
    end)
  -- vim.health is this file, which is not a healthcheck
  unique['vim'] = nil
  local rv = vim.tbl_keys(unique)
  table.sort(rv)
  return rv
end

--- Runs the specified healthchecks.
--- Runs all discovered healthchecks if plugin_names is empty.
---
--- @param mods string command modifiers that affect splitting a window.
--- @param plugin_names string glob of plugin names, split on whitespace. For example, using
---                            `:checkhealth vim.* nvim` will healthcheck `vim.lsp`, `vim.treesitter`
---                            and `nvim` modules.
function M._check(mods, plugin_names)
  local healthchecks = plugin_names == '' and get_healthcheck('*') or get_healthcheck(plugin_names)

  local emptybuf = vim.fn.bufnr('$') == 1 and vim.fn.getline(1) == '' and 1 == vim.fn.line('$')

  -- When no command modifiers are used:
  -- - If the current buffer is empty, open healthcheck directly.
  -- - If not specified otherwise open healthcheck in a tab.
  local buf_cmd = #mods > 0 and (mods .. ' sbuffer') or emptybuf and 'buffer' or 'tab sbuffer'

  local bufnr = vim.api.nvim_create_buf(true, true)
  vim.cmd(buf_cmd .. ' ' .. bufnr)

  if vim.fn.bufexists('health://') == 1 then
    vim.cmd.bwipe('health://')
  end
  vim.cmd.file('health://')
  vim.cmd.setfiletype('checkhealth')

  -- This should only happen when doing `:checkhealth vim`
  if next(healthchecks) == nil then
    vim.fn.setline(1, 'ERROR: No healthchecks found.')
    return
  end
  vim.cmd.redraw()
  vim.print('Running healthchecks...')

  for name, value in vim.spairs(healthchecks) do
    local func = value[1]
    local type = value[2]
    s_output = {}

    if func == '' then
      s_output = {}
      M.error('No healthcheck found for "' .. name .. '" plugin.')
    end
    if type == 'v' then
      vim.fn.call(func, {})
    else
      local f = assert(loadstring(func))
      local ok, output = pcall(f)
      if not ok then
        M.error(
          string.format('Failed to run healthcheck for "%s" plugin. Exception:\n%s\n', name, output)
        )
      end
    end
    -- in the event the healthcheck doesn't return anything
    -- (the plugin author should avoid this possibility)
    if next(s_output) == nil then
      s_output = {}
      M.error('The healthcheck report for "' .. name .. '" plugin is empty.')
    end
    local header = { string.rep('=', 78), name .. ': ' .. func, '' }
    -- remove empty line after header from report_start
    if s_output[1] == '' then
      local tmp = {} ---@type string[]
      for i = 2, #s_output do
        tmp[#tmp + 1] = s_output[i]
      end
      s_output = {}
      for _, v in ipairs(tmp) do
        s_output[#s_output + 1] = v
      end
    end
    s_output[#s_output + 1] = ''
    s_output = vim.list_extend(header, s_output)
    vim.fn.append('$', s_output)
    vim.cmd.redraw()
  end

  -- Clear the 'Running healthchecks...' message.
  vim.cmd.redraw()
  vim.print('')
end

return M
