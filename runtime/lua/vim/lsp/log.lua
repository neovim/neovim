-- Logger for language client plugin.

local log = {}

-- FIXME: DOC
-- Should be exposed in the vim docs.
--
-- Log level dictionary with reverse lookup as well.
--
-- Can be used to lookup the number from the name or the name from the number.
-- Levels by name: "TRACE", "DEBUG", "INFO", "WARN", "ERROR", "OFF"
-- Level numbers begin with "TRACE" at 0
log.levels = vim.deepcopy(vim.log.levels)

-- Default log level is warn.
local current_log_level = log.levels.WARN
local log_date_format = '%F %H:%M:%S'
local format_func = function(arg)
  return vim.inspect(arg, { newline = '' })
end

do
  ---@private
  local function notify(msg, level)
    if vim.in_fast_event() then
      vim.schedule(function()
        vim.notify(msg, level)
      end)
    else
      vim.notify(msg, level)
    end
  end

  local path_sep = vim.loop.os_uname().version:match('Windows') and '\\' or '/'
  ---@private
  local function path_join(...)
    return table.concat(vim.tbl_flatten({ ... }), path_sep)
  end
  local logfilename = path_join(vim.fn.stdpath('log'), 'lsp.log')

  -- TODO: Ideally the directory should be created in open_logfile(), right
  -- before opening the log file, but open_logfile() can be called from libuv
  -- callbacks, where using fn.mkdir() is not allowed.
  vim.fn.mkdir(vim.fn.stdpath('log'), 'p')

  --- Returns the log filename.
  ---@returns (string) log filename
  function log.get_filename()
    return logfilename
  end

  local logfile, openerr
  ---@private
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
      notify(err_msg, vim.log.levels.ERROR)
      return false
    end

    local log_info = vim.loop.fs_stat(logfilename)
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

  for level, levelnr in pairs(log.levels) do
    -- Also export the log level on the root object.
    log[level] = levelnr
    -- FIXME: DOC
    -- Should be exposed in the vim docs.
    --
    -- Set the lowercase name as the main use function.
    -- If called without arguments, it will check whether the log level is
    -- greater than or equal to this one. When called with arguments, it will
    -- log at that level (if applicable, it is checked either way).
    --
    -- Recommended usage:
    -- ```
    -- local _ = log.warn() and log.warn("123")
    -- ```
    --
    -- This way you can avoid string allocations if the log level isn't high enough.
    if level ~= 'OFF' then
      log[level:lower()] = function(...)
        local argc = select('#', ...)
        if levelnr < current_log_level then
          return false
        end
        if argc == 0 then
          return true
        end
        if not open_logfile() then
          return false
        end
        local info = debug.getinfo(2, 'Sl')
        local header = string.format(
          '[%s][%s] ...%s:%s',
          level,
          os.date(log_date_format),
          string.sub(info.short_src, #info.short_src - 15),
          info.currentline
        )
        local parts = { header }
        for i = 1, argc do
          local arg = select(i, ...)
          if arg == nil then
            table.insert(parts, 'nil')
          else
            table.insert(parts, format_func(arg))
          end
        end
        logfile:write(table.concat(parts, '\t'), '\n')
        logfile:flush()
      end
    end
  end
end

-- This is put here on purpose after the loop above so that it doesn't
-- interfere with iterating the levels
vim.tbl_add_reverse_lookup(log.levels)

--- Sets the current log level.
---@param level (string|integer) One of `vim.lsp.log.levels`
function log.set_level(level)
  if type(level) == 'string' then
    current_log_level =
      assert(log.levels[level:upper()], string.format('Invalid log level: %q', level))
  else
    assert(type(level) == 'number', 'level must be a number or string')
    assert(log.levels[level], string.format('Invalid log level: %d', level))
    current_log_level = level
  end
end

--- Gets the current log level.
---@return string current log level
function log.get_level()
  return current_log_level
end

--- Sets formatting function used to format logs
---@param handle function function to apply to logging arguments, pass vim.inspect for multi-line formatting
function log.set_format_func(handle)
  assert(handle == vim.inspect or type(handle) == 'function', 'handle must be a function')
  format_func = handle
end

--- Checks whether the level is sufficient for logging.
---@param level integer log level
---@returns (bool) true if would log, false if not
function log.should_log(level)
  return level >= current_log_level
end

return log
-- vim:sw=2 ts=2 et
