--- @brief
---
--- The |vim.log| module provides file-backed logger instances.
---
--- Use `vim.log.new()` to create a logger, it exposes five writer functions:
--- `trace()`, `debug()`, `info()`, `warn()`, and `error()`.
--- They are correspond to log levels defined by |vim.log.levels|.
---
--- Example:
---
--- ```lua
--- local log = vim.log.new({ name = 'my-plugin', })
--- -- By default, logs will be written to {name}.log under `stdpath('log')`.
---
--- log.error('request failed', 'timeout')
--- -- This will write a line like the following to the log file:
--- --   [ERROR][2024-01-01 12:00:00] source.lua:123    request failed    timeout
---
--- -- Set the log level to `INFO`, otherwise the `info()` call below would be ignored,
--- -- since the default level is `WARN`.
--- vim.log.set_level(log, vim.log.levels.INFO)
--- log.info('starting', { buf = vim.api.nvim_get_current_buf() })
--- -- This will write a line like the following to the log file:
--- --   [INFO][2024-01-01 12:01:00] source.lua:124    starting    { buf = 1 }
--- ```
---
--- You can also provide a custom formatter function to customize the log output format.

---@class vim.Log
---
--- Display name used in notifications emitted by the logger.
---@field private name string
---
--- Minimum level that will be written.
---@field private current_level integer
---
--- Function used to format a log entry.
---@field private format_func fun(current_level: vim.log.levels, level:vim.log.levels, ...): string?
---
--- Path of the log file.
---@field private filename string
---
--- Internal state for the log file handle. `nil` until the file is opened.
---@field private logfile file*?
---
--- Internal state for the log file open error.
---@field private openerr string?
---
--- Writes a message at `vim.log.levels.TRACE`.
---@field trace fun(...:any): boolean?
---
--- Writes a message at `vim.log.levels.DEBUG`.
---@field debug fun(...:any): boolean?
---
--- Writes a message at `vim.log.levels.INFO`.
---@field info fun(...:any): boolean?
---
--- Writes a message at `vim.log.levels.WARN`.
---@field warn fun(...:any): boolean?
---
--- Writes a message at `vim.log.levels.ERROR`.
---@field error fun(...:any): boolean?
local M = {}

---@enum vim.log.levels
---@nodoc
M.levels = {
  TRACE = 0,
  DEBUG = 1,
  INFO = 2,
  WARN = 3,
  ERROR = 4,
  OFF = 5,
}

local level_names = {
  [0] = 'TRACE',
  [1] = 'DEBUG',
  [2] = 'INFO',
  [3] = 'WARN',
  [4] = 'ERROR',
  [5] = 'OFF',
}

local log_date_format = '%F %H:%M:%S'

--- Default formatter used by |vim.log.new()|.
---
--- Formats a message as:
--- `[LEVEL][YYYY-MM-DD HH:MM:SS] source.lua:line<TAB>arg1<TAB>arg2`
---
---@param current_level vim.log.levels
---@param level vim.log.levels
---@return string?
local function default_format_func(current_level, level, ...)
  if level < current_level then
    return nil
  end

  -- Stack shape:
  --   default_format_func <- create_writer closure <- user callsite
  local info = debug.getinfo(3, 'Sl')
  local header = string.format(
    '[%s][%s] %s:%s',
    level_names[level],
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

---@class vim.log.new.Opts
---@inlinedoc
---
--- Display name used in notifications emitted by the logger.
---@field name string
---
--- Minimum level that will be written.
--- (default: `vim.log.levels.WARN`)
---@field current_level? vim.log.levels
---
--- Formatter used for each log entry.
--- Receives the logger's current level, the message level, and the values passed to the writer.
--- Return a string to write an entry, or `nil` to skip it.
---@field format_func? fun(current_level: vim.log.levels, level: vim.log.levels, ...): string?

--- Creates a logger instance.
---
--- The logger writes formatted messages to a file,
--- using a per-instance log level and formatting function.
---
---@param opts vim.log.new.Opts
---@return vim.Log
function M.new(opts)
  vim.validate('opts', opts, 'table')
  vim.validate('opts.name', opts.name, 'string')
  vim.validate('opts.current_level', opts.current_level, 'number', true)
  vim.validate('opts.format_func', opts.format_func, 'function', true)

  local filename = vim.fs.joinpath(vim.fn.stdpath('log'), opts.name:lower() .. '.log')
  local log_dir = vim.fs.dirname(filename)
  if log_dir then
    -- TODO: Ideally, directory creation should be delayed until open_file(), right before
    -- opening the log file, but open() can be called from libuv callbacks,
    -- where using fn.mkdir() is not allowed.
    vim.fn.mkdir(log_dir, 'p')
  end

  local log = setmetatable({
    name = opts.name,
    filename = filename,
    current_level = opts.current_level or M.levels.WARN,
    format_func = opts.format_func or default_format_func,
  }, { __index = M })
  log.trace = log:create_writer(M.levels.TRACE)
  log.debug = log:create_writer(M.levels.DEBUG)
  log.info = log:create_writer(M.levels.INFO)
  log.warn = log:create_writer(M.levels.WARN)
  log.error = log:create_writer(M.levels.ERROR)

  return log
end

---@param msg string
---@param level? vim.log.levels
local function notify(msg, level)
  if vim.in_fast_event() then
    vim.schedule(function()
      vim.notify(msg, level)
    end)
  else
    vim.notify(msg, level)
  end
end

--- Opens the log file on first use.
---
--- Writes a `[START]` marker when the file is opened successfully.
---
---@package
---@return boolean # `true` if the file is open, `false` on error.
function M:open_file()
  if self.logfile then
    return true
  end
  if self.openerr then
    return false
  end

  self.logfile, self.openerr = io.open(self.filename, 'a+')
  if not self.logfile then
    local err_msg = string.format('Failed to open %s log file: %s', self.name, self.openerr)
    notify(err_msg, M.levels.ERROR)
    return false
  end

  local log_info = vim.uv.fs_stat(self.filename)
  if log_info and log_info.size > 1e9 then
    local warn_msg = string.format(
      '%s log is large (%d MB): %s',
      self.name,
      log_info.size / (1000 * 1000),
      self.filename
    )
    notify(warn_msg)
  end

  -- Start message for logging
  self.logfile:write(
    string.format('[START][%s] %s logging initiated\n', os.date(log_date_format), self.name)
  )
  return true
end

--- Creates a writer function for a specific log level.
---
---@package
---@param level vim.log.levels
---@return fun(...:any): boolean? # Returns `false` if the log file could not be opened.
function M:create_writer(level)
  return function(...)
    local argc = select('#', ...)
    if argc == 0 then
      return true
    end
    if not self:open_file() then
      return false
    end
    local message = self.format_func(self.current_level, level, ...)
    if message then
      assert(self.logfile)
      self.logfile:write(message)
      self.logfile:flush()
    end
  end
end

--- Sets the current log level.
---
--- Entries below this level are skipped.
---
---@param log vim.Log
---@param level vim.log.levels
function M.set_level(log, level)
  vim.validate('level', level, 'number')
  log.current_level = level
end

--- Gets the current log level.
---@param log vim.Log
---@return vim.log.levels
function M.get_level(log)
  return log.current_level
end

--- Sets the formatter used to produce log entries.
---
--- The formatter receives the logger's current level, the message level,
--- and the values passed to the writer method.
--- Return a string to write an entry, or `nil` to skip it.
---
---@param log vim.Log
---@param func fun(current_level: vim.log.levels, level: vim.log.levels, ...): string?
function M.set_format_func(log, func)
  vim.validate('func', func, function(f)
    return type(f) == 'function' or f == vim.inspect
  end, false, 'func must be a function')

  log.format_func = func
end

return M
