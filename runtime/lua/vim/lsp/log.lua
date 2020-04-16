-- Logger for language client plugin.

local loggers = {}

local raw_levels = {
  TRACE = 0;
  DEBUG = 1;
  INFO  = 2;
  WARN  = 3;
  ERROR = 4;
}

-- Log level dictionary with reverse lookup as well.
--
-- Can be used to lookup the number from the name or the name from the number.
-- Levels by name: 'trace', 'debug', 'info', 'warn', 'error'
-- Level numbers begin with 'trace' at 0
local levels = vim.deepcopy(raw_levels)
vim.tbl_add_reverse_lookup(levels)

local log_date_format = "%FT%H:%M:%SZ%z"


local function create_logger(filename)
  local logger = loggers[filename]
  if logger then
    return logger
  end
  logger = {}
  loggers[filename] = logger

  local path_sep = vim.loop.os_uname().sysname == "Windows" and "\\" or "/"
  local function path_join(...)
    return table.concat(vim.tbl_flatten{...}, path_sep)
  end

  local logfilename = path_join(vim.fn.stdpath('data'), filename)
  local current_log_level = levels.WARN

  function logger.get_filename()
    return logfilename
  end

  function logger.set_level(level)
    if type(level) == 'string' then
      current_log_level = assert(levels[level:upper()], string.format("Invalid log level: %q", level))
    else
      assert(type(level) == 'number', "level must be a number or string")
      assert(levels[level], string.format("Invalid log level: %d", level))
      current_log_level = level
    end
  end

  vim.fn.mkdir(vim.fn.stdpath('data'), "p")
  local logfile = assert(io.open(logfilename, "a+"))

  function logger.close()
    loggers[filename] = nil
    logfile:close()
  end

  for level, levelnr in pairs(raw_levels) do
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
    logger[level:lower()] = function(...)
      local argc = select("#", ...)
      if levelnr < current_log_level then return false end
      if argc == 0 then return true end
      local info = debug.getinfo(2, "Sl")
      local fileinfo = string.format("%s:%s", info.short_src, info.currentline)
      local parts = { table.concat({"[", level, "]", os.date(log_date_format), "]", fileinfo, "]"}, " ") }
      for i = 1, argc do
        local arg = select(i, ...)
        if arg == nil then
          table.insert(parts, "nil")
        else
          table.insert(parts, vim.inspect(arg))
        end
      end
      logfile:write(table.concat(parts, '\t'), "\n")
      logfile:flush()
    end
  end
  -- Add some space to make it easier to distinguish different neovim runs.
  logfile:write("\n")
  return logger
end


-- Emulate the interface `log.lua` had before the addition of `create_logger`
local lsp_logger = create_logger('vim-lsp.log')
lsp_logger.create_logger = create_logger
for level, levelnr in pairs(levels) do
  lsp_logger[level] = levelnr
end

-- Return whether the level is sufficient for logging.
-- @param level number log level
function lsp_logger.should_log(level)
  return level >= lsp_logger.current_log_level
end


return lsp_logger
-- vim:sw=2 ts=2 et
