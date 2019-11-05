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
local LOG_LEVEL = LOG_LEVELS.WARN
local DATE_FORMAT = "%FT%H:%M:%SZ%z"

local log = {}
do
  local path_sep = vim.loop.os_uname().sysname == "Windows" and "\\" or "/"
  local function path_join(...)
    return table.concat(vim.tbl_flatten{...}, path_sep)
  end
  local logfilename = path_join(vim.fn.stdpath('data'), 'language_server_client.log')
  local logfile = assert(io.open(logfilename, "a+"))
  for level, levelnr in pairs(LOG_LEVELS) do
    log[level] = levelnr
    -- log["should_"..level:lower()] = function() return levelnr >= LOG_LEVEL end
    -- log[level:sub(1,1)] = function() return levelnr >= LOG_LEVEL end
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
      logfile:flush() -- TODO?
    end
  end
  logfile:write(string.rep("\n", 30)) -- TODO delete
end

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

function log.should_log(level)
  return level >= LOG_LEVEL
end

return log
-- vim:sw=2 ts=2 et
