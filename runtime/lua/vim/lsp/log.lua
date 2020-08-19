-- Logger for language client plugin.

local log = {}

-- Log level dictionary with reverse lookup as well.
--
-- Can be used to lookup the number from the name or the name from the number.
-- Levels by name: 'trace', 'debug', 'info', 'warn', 'error'
-- Level numbers begin with 'trace' at 0
log.levels = {
  TRACE = 0;
  DEBUG = 1;
  INFO  = 2;
  WARN  = 3;
  ERROR = 4;
}

-- FIXME: Hack for docs; these functions get overwritten later
--- Log a message at level TRACE.
--@see |vim.lsp.log.debug()| for details
function log.trace(...) end -- luacheck: no unused args
-- The description is on this function because it's first alphabetically

--- Log a message at level DEBUG.
---
--- Recommended usage:
---
---<pre>
---    log.debug("123")
---</pre>
---
--- Only log if the log level is high enough (this way you can avoid string
--- allocations):
---
---<pre>
---    log.debug() and log.debug("123")
---</pre>
---
--@param ... (any, optional) When called with arguments, log them at level
---DEBUG (if applicable, it is checked either way). Tables are converted to
---strings using |vim.inspect()|.
---When called without arguments, it will check whether the
---log level is greater than or equal to this one.
--@returns `nil` when called with arguments. When called without arguments,
---returns the same as |vim.lsp.log.should_log()|.
function log.debug(...) end --luacheck: no unused args
--- Log a message at level INFO.
--@see |vim.lsp.log.debug()| for details
function log.info(...) end --luacheck: no unused args
--- Log a message at level WARN (the default log level).
--@see |vim.lsp.log.debug()| for details
function log.warn(...) end --luacheck: no unused args
--- Log a message at level ERROR.
--@see |vim.lsp.log.debug()| for details
function log.error(...) end --luacheck: no unused args

-- Default log level is warn.
local current_log_level = log.levels.WARN
local log_date_format = "%FT%H:%M:%S%z"

do
  local path_sep = vim.loop.os_uname().sysname == "Windows" and "\\" or "/"
  local function path_join(...)
    return table.concat(vim.tbl_flatten{...}, path_sep)
  end
  local logfilename = path_join(vim.fn.stdpath('data'), 'lsp.log')

  --- Return the log filename.
  function log.get_filename()
    return logfilename
  end

  vim.fn.mkdir(vim.fn.stdpath('data'), "p")
  local logfile = assert(io.open(logfilename, "a+"))
  for level, levelnr in pairs(log.levels) do
    -- Also export the log level on the root object.
    log[level] = levelnr
    -- Set the lowercase name as the main use function.
    log[level:lower()] = function(...)
      local argc = select("#", ...)
      if argc == 0 then return log.should_log(levelnr) end
      local info = debug.getinfo(2, "Sl")
      local fileinfo = string.format("%s:%s", info.short_src, info.currentline)
      local parts = { table.concat({"[", level, "]", os.date(log_date_format), "]", fileinfo, "]"}, " ") }
      for i = 1, argc do
        local arg = select(i, ...)
        if arg == nil then
          table.insert(parts, "nil")
        else
          table.insert(parts, vim.inspect(arg, {newline=''}))
        end
      end
      logfile:write(table.concat(parts, '\t'), "\n")
      logfile:flush()
    end
  end
  -- Add some space to make it easier to distinguish different neovim runs.
  logfile:write("\n")
end

-- This is put here on purpose after the loop above so that it doesn't
-- interfere with iterating the levels
vim.tbl_add_reverse_lookup(log.levels)

function log.set_level(level)
  if type(level) == 'string' then
    current_log_level = assert(log.levels[level:upper()], string.format("Invalid log level: %q", level))
  else
    assert(type(level) == 'number', "level must be a number or string")
    assert(log.levels[level], string.format("Invalid log level: %d", level))
    current_log_level = level
  end
end

-- Return whether the level is sufficient for logging.
-- @param level number log level
function log.should_log(level)
  return level >= current_log_level
end

return log
-- vim:sw=2 ts=2 et
