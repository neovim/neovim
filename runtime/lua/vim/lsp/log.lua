--- @brief
--- The `vim.lsp.log` module provides logging for the Nvim LSP client.
---
--- When debugging language servers, it is helpful to enable extra-verbose logging of the LSP client
--- RPC events. Example:
--- ```lua
--- vim.lsp.set_log_level 'trace'
--- require('vim.lsp.log').set_format_func(vim.inspect)
--- ```
---
--- Then try to run the language server, and open the log with:
--- ```vim
--- :lua vim.cmd('tabnew ' .. vim.lsp.get_log_path())
--- ```
---
--- (Or use `:LspLog` if you have nvim-lspconfig installed.)
---
--- Note:
--- - Remember to DISABLE verbose logging ("debug" or "trace" level), else you may encounter
---   performance issues.
--- - "ERROR" messages containing "stderr" only indicate that the log was sent to stderr. Many
---   servers send harmless messages via stderr.

local log = {}

local log_levels = vim.log.levels

--- Log level dictionary with reverse lookup as well.
---
--- Can be used to lookup the number from the name or the name from the number.
--- Levels by name: "TRACE", "DEBUG", "INFO", "WARN", "ERROR", "OFF"
--- Level numbers begin with "TRACE" at 0
--- @type table<string,integer> | table<integer, string>
--- @nodoc
log.levels = vim.deepcopy(log_levels)

-- Default log level is warn.
local current_log_level = log_levels.WARN

local log_date_format = '%F %H:%M:%S'

--- Default formatting function.
--- @param level? string
local function format_func(level, ...)
  if log_levels[level] < current_log_level then
    return nil
  end

  local info = debug.getinfo(2, 'Sl')
  local header = string.format(
    '[%s][%s] %s:%s',
    level,
    os.date(log_date_format),
    info.short_src,
    info.currentline
  )
  local parts = { header }
  local argc = select('#', ...)
  for i = 1, argc do
    local arg = select(i, ...)
    table.insert(parts, arg == nil and 'nil' or vim.inspect(arg, { newline = ' ', indent = '' }))
  end
  return table.concat(parts, '\t') .. '\n'
end

local function notify(msg, level)
  if vim.in_fast_event() then
    vim.schedule(function()
      vim.notify(msg, level)
    end)
  else
    vim.notify(msg, level)
  end
end

local logfilename = vim.fs.joinpath(vim.fn.stdpath('log') --[[@as string]], 'lsp.log')

-- TODO: Ideally the directory should be created in open_logfile(), right
-- before opening the log file, but open_logfile() can be called from libuv
-- callbacks, where using fn.mkdir() is not allowed.
vim.fn.mkdir(vim.fn.stdpath('log') --[[@as string]], 'p')

--- Returns the log filename.
---@return string log filename
function log.get_filename()
  return logfilename
end

--- @param s string
function log._set_filename(s)
  logfilename = s
end

--- @type file*?, string?
local logfile, openerr

--- Opens log file. Returns true if file is open, false on error
local function open_logfile()
  -- Try to open file only once
  if logfile then
    return true
  end
  if openerr then
    return false
  end

  logfile, openerr = io.open(logfilename, 'a+')
  if not logfile then
    local err_msg = string.format('Failed to open LSP client log file: %s', openerr)
    notify(err_msg, log_levels.ERROR)
    return false
  end

  local log_info = vim.uv.fs_stat(logfilename)
  if log_info and log_info.size > 1e9 then
    local warn_msg = string.format(
      'LSP client log is large (%d MB): %s',
      log_info.size / (1000 * 1000),
      logfilename
    )
    notify(warn_msg)
  end

  -- Start message for logging
  logfile:write(string.format('[START][%s] LSP logging initiated\n', os.date(log_date_format)))
  return true
end

for level, levelnr in pairs(log_levels) do
  -- Also export the log level on the root object.
  ---@diagnostic disable-next-line: no-unknown
  log[level] = levelnr

  -- Add a reverse lookup.
  log.levels[levelnr] = level
end

--- @param level string
--- @return fun(...:any): boolean?
local function create_logger(level)
  return function(...)
    local argc = select('#', ...)
    if argc == 0 then
      return true
    end
    if not open_logfile() then
      return false
    end
    local message = format_func(level, ...)
    if message then
      assert(logfile)
      logfile:write(message)
      logfile:flush()
    end
  end
end

-- If called without arguments, it will check whether the log level is
-- greater than or equal to this one. When called with arguments, it will
-- log at that level (if applicable, it is checked either way).

--- @nodoc
log.debug = create_logger('DEBUG')

--- @nodoc
log.error = create_logger('ERROR')

--- @nodoc
log.info = create_logger('INFO')

--- @nodoc
log.trace = create_logger('TRACE')

--- @nodoc
log.warn = create_logger('WARN')

--- Sets the current log level.
---@param level (string|integer) One of |vim.log.levels|
function log.set_level(level)
  vim.validate('level', level, { 'string', 'number' })

  if type(level) == 'string' then
    current_log_level =
      assert(log.levels[level:upper()], string.format('Invalid log level: %q', level))
  else
    assert(log.levels[level], string.format('Invalid log level: %d', level))
    current_log_level = level
  end
end

--- Gets the current log level.
---@return integer current log level
function log.get_level()
  return current_log_level
end

--- Sets the formatting function used to format logs. If the formatting function returns nil, the entry won't
--- be written to the log file.
---@param handle fun(level:string, ...): string? Function to apply to log entries. The default will log the level,
---date, source and line number of the caller, followed by the arguments.
function log.set_format_func(handle)
  vim.validate('handle', handle, function(h)
    return type(h) == 'function' or h == vim.inspect
  end, false, 'handle must be a function')

  format_func = handle
end

--- Checks whether the level is sufficient for logging.
---@deprecated
---@param level integer log level
---@return boolean : true if would log, false if not
function log.should_log(level)
  vim.deprecate('vim.lsp.log.should_log', 'vim.lsp.log.set_format_func', '0.13')

  vim.validate('level', level, 'number')

  return level >= current_log_level
end

return log
