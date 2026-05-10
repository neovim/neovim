--- @brief
---
--- The |vim.log| module provides file-backed logger instances.
---
--- Use `vim.log.new()` to create a logger, which exposes a writer function for
--- each |vim.log.levels| level: `trace()`, `debug()`, `info()`, `warn()`, and `error()`.
---
--- Example:
---
--- ```lua
--- local log = vim.log.new('my-plugin')
--- -- By default, logs will be written to {name}.log under `stdpath('log')`.
---
--- log.error('request failed', 'timeout')
--- -- This will write a line like the following to the log file:
--- --   [ERROR][2024-01-01 12:00:00] source.lua:123    request failed    timeout
---
--- -- Set the log level to `INFO`, otherwise the `info()` call below would be ignored,
--- -- since the default level is `WARN`.
--- log:set_level(vim.log.levels.INFO)
--- log.info('starting', { buf = vim.api.nvim_get_current_buf() })
--- -- This will write a line like the following to the log file:
--- --   [INFO][2024-01-01 12:01:00] source.lua:124    starting    { buf = 1 }
--- ```
---
--- To customize the output format, override `log.fmt` directly:
--- ```lua
--- log.fmt = function(current_level, level, ...) ... end
--- ```

---@class vim.Log
---
--- Display name used in notifications emitted by the logger.
---@field private name string
---
--- Minimum level that will be written.
---@field private level integer
---
--- Function used to format a log entry. Override directly to customize output.
---@field fmt fun(min_level: vim.log.levels, level: vim.log.levels, ...): string?
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
---@param min_level vim.log.levels
---@param level vim.log.levels
---@return string?
local function default_fmt(min_level, level, ...)
  if level < min_level then
    return nil
  end

  -- Stack shape:
  --   fmt <- create_writer closure <- user callsite
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
--- Minimum level that will be written.
--- (default: `vim.log.levels.WARN`)
---@field level? vim.log.levels
---
--- Formatter used for each log entry.
--- Receives the logger's minimum level, the message level, and the values passed to the writer.
--- Return a string to write an entry, or `nil` to skip it.
---@field fmt? fun(min_level: vim.log.levels, level: vim.log.levels, ...): string?

--- Creates a logger instance.
---
--- The logger writes formatted messages to a file,
--- using a per-instance log level and formatting function.
---
---@param name string Display name used in notifications emitted by the logger,
---                   and as the log file basename (`{name}.log` under `stdpath('log')`).
---@param opts? vim.log.new.Opts
---@return vim.Log
function M.new(name, opts)
  vim.validate('name', name, 'string')
  vim.validate('opts', opts, 'table', true)
  opts = opts or {}
  vim.validate('opts.level', opts.level, 'number', true)
  vim.validate('opts.fmt', opts.fmt, 'function', true)

  local filename = vim.fs.joinpath(vim.fn.stdpath('log'), name:lower() .. '.log')
  local log_dir = vim.fs.dirname(filename)
  if log_dir then
    -- TODO: Ideally, directory creation should be delayed until open_file(), right before
    -- opening the log file, but open() can be called from libuv callbacks,
    -- where using fn.mkdir() is not allowed.
    vim.fn.mkdir(log_dir, 'p')
  end

  local log = setmetatable({
    name = name,
    filename = filename,
    level = opts.level or M.levels.WARN,
    fmt = opts.fmt or default_fmt,
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
--- The returned writer supports a "should-log" check: calling it with no
--- arguments returns `true` if the level is enabled, `false` otherwise. This
--- lets callers cheaply guard expensive message construction:
--- ```lua
--- if log.trace() then
---   log.trace('heavy', vim.inspect(big_table))
--- end
--- ```
---
---@package
---@param level vim.log.levels
---@return fun(...:any):boolean?
function M:create_writer(level)
  return function(...)
    if level < self.level then
      return false
    end
    local argc = select('#', ...)
    if argc == 0 then
      return true
    end
    if not self:open_file() then
      return false
    end
    -- TODO(justinmk): should we use `self:fmt()` here?
    local message = self.fmt(self.level, level, ...)
    if message then
      assert(self.logfile)
      self.logfile:write(message)
      -- TODO(justinmk):
      -- - Do this less often... May require a sharing the file handle.
      --   All logger(x) instances should route through the same sink(x) instance.
      -- - When/where is logfile closed?
      self.logfile:flush()
    end
  end
end

--- Sets the current log-level. Messages below this level are skipped (not logged).
---
---@param log vim.Log
---@param level vim.log.levels
function M.set_level(log, level)
  vim.validate('level', level, 'number')
  log.level = level
end

--- Gets the current log-level.
---
---@param log vim.Log
---@return vim.log.levels
function M.get_level(log)
  return log.level
end

return M
