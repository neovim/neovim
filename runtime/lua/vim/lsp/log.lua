-- Logger for language client plugin.

local log = {}

-- FIXME: DOC
-- Should be exposed in the vim docs.
--
-- Log level dictionary with reverse lookup as well.
--
-- Can be used to lookup the number from the name or the name from the number.
-- Levels by name: 'trace', 'debug', 'info', 'warn', 'error'
-- Level numbers begin with 'trace' at 0
log.levels = vim.deepcopy(vim.log.levels)

local path_sep = vim.loop.os_uname().version:match("Windows") and "\\" or "/"
---@private
local function path_join(...)
  return table.concat(vim.tbl_flatten{...}, path_sep)
end

---@private
local get_parent = (function()
  local formatted = string.format("^(.+)%s[^%s]+", path_sep, path_sep)
  return function(abs_path)
    return abs_path:match(formatted)
  end
end)()

local config = {
  -- Default log level is warn.
	level = log.levels.WARN,
	date_format = "%F %H:%M:%S",
  format_func = function(arg) return vim.inspect(arg, {newline=''}) end,
  filepath = path_join(vim.fn.stdpath('cache'), 'lsp.log')
}

log.new = function(opts)

  local log_basedir = get_parent(opts.filepath)
  vim.fn.mkdir(log_basedir, "p")
  local logger = assert(io.open(opts.filepath, "a+"))

  local log_info = vim.loop.fs_stat(opts.filepath)
  if log_info and log_info.size > 1e9 then
    local warn_msg = string.format(
      "LSP client log is large (%d MB): %s",
      log_info.size / (1000 * 1000),
      opts.filepath
    )
    vim.notify(warn_msg)
  end

	-- Start message for logging
	logger:write(string.format("[START][%s] LSP logging initiated\n", os.date(opts.date_format)))
	logger:close()

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
    log[level:lower()] = function(...)
      local argc = select("#", ...)
      if levelnr < opts.level then return false end
      if argc == 0 then return true end
      local info = debug.getinfo(2, "Sl")
      local header = string.format("[%s][%s] ...%s:%s", level, os.date(opts.date_format), string.sub(info.short_src, #info.short_src - 15), info.currentline)
      local parts = { header }
      for i = 1, argc do
        local arg = select(i, ...)
        if arg == nil then
          table.insert(parts, "nil")
        else
          table.insert(parts, opts.format_func(arg))
        end
      end
      -- we need to explicitly open it again here in case the filepath got changed
      local fp = assert(io.open(opts.filepath, "a+"))
      fp:write(table.concat(parts, '\t'), "\n")
      fp:flush()
    end
  end
end


log.new(config)

--- Sets the current log level.
---@param level number see |vim.log.levels|
function log.set_level(level)
  if type(level) == 'string' then
    config.level = assert(log.levels[level:upper()], string.format("Invalid log level: %q", level))
  else
    assert(type(level) == 'number', "level must be a number or string")
    assert(log.levels[level], string.format("Invalid log level: %d", level))
    config.level = level
  end
end

--- Gets the current log level.
---@returns number current log level, see |vim.log.levels|
function log.get_level()
  return config.level
end

--- Sets formatting function used to format logs
---@param handle function function to apply to logging arguments, pass vim.inspect for multi-line formatting
function log.set_format_func(handle)
  assert(handle == vim.inspect or type(handle) == 'function', "handle must be a function")
  config.format_func = handle
end

--- Checks whether the level is sufficient for logging.
---@param level number log level
---@returns boolean true if would log, false if not
function log.should_log(level)
  return level >= config.level
end

--- Returns the log filename.
---@returns string log filename
function log.get_filename()
  return config.filepath
end

--- Sets the log filename.
---@param name string full path to the logfile
function log.set_filename(name)
  config.filepath = name
end

-- This is put here on purpose after the loop above so that it doesn't
-- interfere with iterating the levels
vim.tbl_add_reverse_lookup(log.levels)

return log
-- vim:sw=2 ts=2 et
