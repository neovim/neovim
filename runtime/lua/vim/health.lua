local M = {}

local s_output = {}

-- Returns the fold text of the current healthcheck section
function M.foldtext()
  local foldtext = vim.fn.foldtext()

  if vim.bo.filetype ~= 'checkhealth' then
    return foldtext
  end

  if vim.b.failedchecks == nil then
    vim.b.failedchecks = vim.empty_dict()
  end

  if vim.b.failedchecks[foldtext] == nil then
    local warning = '- WARNING '
    local warninglen = string.len(warning)
    local err = '- ERROR '
    local errlen = string.len(err)
    local failedchecks = vim.b.failedchecks
    failedchecks[foldtext] = false

    local foldcontent = vim.api.nvim_buf_get_lines(0, vim.v.foldstart - 1, vim.v.foldend, false)
    for _, line in ipairs(foldcontent) do
      if string.sub(line, 1, warninglen) == warning or string.sub(line, 1, errlen) == err then
        failedchecks[foldtext] = true
        break
      end
    end

    vim.b.failedchecks = failedchecks
  end

  return vim.b.failedchecks[foldtext] and '+WE' .. foldtext:sub(4) or foldtext
end

-- From a path return a list [{name}, {func}, {type}] representing a healthcheck
local function filepath_to_healthcheck(path)
  path = vim.fs.normalize(path)
  local name
  local func
  local filetype
  if path:find('vim$') then
    name = vim.fs.basename(path):gsub('%.vim$', '')
    func = 'health#' .. name .. '#check'
    filetype = 'v'
  else
    local subpath = path:gsub('.*lua/', '')
    if vim.fs.basename(subpath) == 'health.lua' then
      -- */health.lua
      name = vim.fs.dirname(subpath)
    else
      -- */health/init.lua
      name = vim.fs.dirname(vim.fs.dirname(subpath))
    end
    name = name:gsub('/', '.')

    func = 'require("' .. name .. '.health").check()'
    filetype = 'l'
  end
  return { name, func, filetype }
end

-- Returns { {name, func, type}, ... } representing healthchecks
local function get_healthcheck_list(plugin_names)
  local healthchecks = {}
  plugin_names = vim.split(plugin_names, ' ')
  for _, p in pairs(plugin_names) do
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
      local unique_paths = {}
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

-- Returns {name: [func, type], ..} representing healthchecks
local function get_healthcheck(plugin_names)
  local health_list = get_healthcheck_list(plugin_names)
  local healthchecks = {}
  for _, c in pairs(health_list) do
    if c[1] ~= 'vim' then
      healthchecks[c[1]] = { c[2], c[3] }
    end
  end

  return healthchecks
end

-- Indents lines *except* line 1 of a string if it contains newlines.
local function indent_after_line1(s, columns)
  local lines = vim.split(s, '\n')
  local indent = string.rep(' ', columns)
  for i = 2, #lines do
    lines[i] = indent .. lines[i]
  end
  return table.concat(lines, '\n')
end

-- Changes ':h clipboard' to ':help |clipboard|'.
local function help_to_link(s)
  return vim.fn.substitute(s, [[\v:h%[elp] ([^|][^"\r\n ]+)]], [[:help |\1|]], [[g]])
end

-- Format a message for a specific report item.
-- Variable args: Optional advice (string or list)
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

local function collect_output(output)
  vim.list_extend(s_output, vim.split(output, '\n'))
end

-- Starts a new report.
function M.start(name)
  local input = string.format('\n%s ~', name)
  collect_output(input)
end

-- Reports a message in the current section.
function M.info(msg)
  local input = format_report_message('', msg)
  collect_output(input)
end

-- Reports a successful healthcheck.
function M.ok(msg)
  local input = format_report_message('OK', msg)
  collect_output(input)
end

-- Reports a health warning.
-- ...: Optional advice (string or table)
function M.warn(msg, ...)
  local input = format_report_message('WARNING', msg, ...)
  collect_output(input)
end

-- Reports a failed healthcheck.
-- ...: Optional advice (string or table)
function M.error(msg, ...)
  local input = format_report_message('ERROR', msg, ...)
  collect_output(input)
end

local function deprecate(type)
  local before = string.format('vim.health.report_%s()', type)
  local after = string.format('vim.health.%s()', type)
  local message = vim.deprecate(before, after, '0.11')
  if message then
    M.warn(message)
  end
  vim.cmd.redraw()
  vim.print('Running healthchecks...')
end

function M.report_start(name)
  deprecate('start')
  M.start(name)
end
function M.report_info(msg)
  deprecate('info')
  M.info(msg)
end
function M.report_ok(msg)
  deprecate('ok')
  M.ok(msg)
end
function M.report_warn(msg, ...)
  deprecate('warn')
  M.warn(msg, ...)
end
function M.report_error(msg, ...)
  deprecate('error')
  M.error(msg, ...)
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

-- Runs the specified healthchecks.
-- Runs all discovered healthchecks if plugin_names is empty.
function M._check(plugin_names)
  local healthchecks = plugin_names == '' and get_healthcheck('*') or get_healthcheck(plugin_names)

  -- Create buffer and open in a tab, unless this is the default buffer when Nvim starts.
  local emptybuf = vim.fn.bufnr('$') == 1 and vim.fn.getline(1) == '' and 1 == vim.fn.line('$')
  local mod = emptybuf and 'buffer' or 'tab sbuffer'
  local bufnr = vim.api.nvim_create_buf(true, true)
  vim.cmd(mod .. ' ' .. bufnr)

  if vim.fn.bufexists('health://') == 1 then
    vim.cmd.bwipe('health://')
  end
  vim.cmd.file('health://')
  vim.cmd.setfiletype('checkhealth')

  if healthchecks == nil or next(healthchecks) == nil then
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
      local tmp = {}
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
