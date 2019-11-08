-- Logger for language client plugin.
-- You can set log levels, debug, info, warn, error and none, like this.
-- let g:language_server_client_log_level = 'debug'
-- Default value is 'none'.

local LOG_LEVELS = {
  TRACE = 0;
  DEBUG = 1;
  INFO  = 2;
  WARN  = 3;
  ERROR = 4;
  -- FATAL = 4;
}

-- Default log level is warn.
local LOG_LEVEL = LOG_LEVELS.WARN
local DATE_FORMAT = "%FT%H:%M:%SZ%z"

local log = {}
do
  local path_sep = vim.loop.os_uname().sysname == "Windows" and "\\" or "/"
  local function path_join(...)
    return table.concat(vim.tbl_flatten{...}, path_sep)
  end
  local logfilename = path_join(vim.fn.stdpath('data'), 'vim-lsp.log')

  --- Return the log filename.
  function log.get_filename()
    return logfilename
  end

  local logfile = assert(io.open(logfilename, "a+"))
  for level, levelnr in pairs(LOG_LEVELS) do
    -- Also export the log level on the root object.
    log[level] = levelnr
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
    log[level:lower()] = function(...)
      local argc = select("#", ...)
      if levelnr < LOG_LEVEL then return false end
      if argc == 0 then return true end
      local info = debug.getinfo(2, "Sl")
     local fileinfo = string.format("%s:%s", info.short_src, info.currentline)
      local parts = { table.concat({"[", level, "]", os.date(DATE_FORMAT), "]", fileinfo, "]"}, " ") }
--      local parts = {level, os.date(DATE_FORMAT), fileinfo}
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

-- Log level dictionary with reverse lookup as well.
--
-- Can be used to lookup the number from the name or the
-- name from the number.
-- Levels by name: 'trace', 'debug', 'info', 'warn', 'error'
-- Level numbers begin with 'trace' at 0
log.levels = LOG_LEVELS
vim.tbl_add_reverse_lookup(log.levels)

function log.set_level(level)
  if type(level) == 'string' then
    LOG_LEVEL = assert(LOG_LEVELS[level:upper()], string.format("Invalid log level: %q", level))
  else
    assert(type(level) == 'number', "level must be a number or string")
    assert(LOG_LEVELS[level], string.format("Invalid log level: %d", level))
    LOG_LEVEL = level
  end
end

-- Return whether the level is sufficient for logging.
-- @param level number log level
function log.should_log(level)
  return level >= LOG_LEVEL
end

return log
-- vim:sw=2 ts=2 et
