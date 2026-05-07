--- @brief
--- The `vim.lsp.log` module provides logging for the Nvim LSP client.
---
--- When debugging language servers, it is helpful to enable extra-verbose logging of the LSP client
--- RPC events. Example:
--- ```lua
--- vim.lsp.log.set_level 'trace'
--- ```
---
--- Then try to run the language server, and open the log with:
--- ```vim
--- :log lsp
--- ```
---
--- Note:
--- - Remember to DISABLE verbose logging ("debug" or "trace" level), else you may encounter
---   performance issues.
--- - "ERROR" messages containing "stderr" only indicate that the log was sent to stderr. Many
---   servers send harmless messages via stderr.

local M = {}

local log_levels = vim.log.levels

local protocol = require('vim.lsp.protocol')

--- Log level dictionary with reverse lookup as well.
---
--- Can be used to lookup the number from the name or the name from the number.
--- Levels by name: "TRACE", "DEBUG", "INFO", "WARN", "ERROR", "OFF"
--- Level numbers begin with "TRACE" at 0
--- @type table<string,integer> | table<integer, string>
--- @nodoc
M.levels = vim.deepcopy(log_levels)

local log = vim.log.new({
  name = 'LSP',
})

--- Returns the log filename.
---@return string log filename
function M.get_filename()
  ---@diagnostic disable-next-line: invisible
  return log.filename
end

for level, levelnr in pairs(log_levels) do
  -- Also export the log level on the root object.
  ---@diagnostic disable-next-line: no-unknown
  M[level] = levelnr

  -- Add a reverse lookup.
  M.levels[levelnr] = level
end

-- If called without arguments, it will check whether the log level is
-- greater than or equal to this one. When called with arguments, it will
-- log at that level (if applicable, it is checked either way).

--- @nodoc
M.debug = log.debug

--- @nodoc
M.error = log.error

--- @nodoc
M.info = log.info

--- @nodoc
M.trace = log.trace

--- @nodoc
M.warn = log.warn

--- Sets the current log level.
---@param level (string|integer) One of |vim.log.levels|
function M.set_level(level)
  vim.validate('level', level, { 'string', 'number' })

  if type(level) == 'string' then
    level = assert(M.levels[level:upper()], string.format('Invalid log level: %q', level))
  end ---@cast level vim.log.levels
  log:set_level(level)
end

--- Gets the current log level.
---@return integer current log level
function M.get_level()
  return log:get_level()
end

--- Sets the formatting function used to format logs. If the formatting function returns nil, the entry won't
--- be written to the log file.
---@param handle fun(level:string, ...): string? Function to apply to log entries. The default will log the level,
---date, source and line number of the caller, followed by the arguments.
function M.set_format_func(handle)
  log:set_format_func(function(_, level, ...)
    return handle(M.levels[level], ...)
  end)
end

--- Checks whether the level is sufficient for logging.
---@deprecated
---@param level integer log level
---@return boolean : true if would log, false if not
function M.should_log(level)
  vim.deprecate('vim.lsp.log.should_log', 'vim.lsp.log.set_format_func', '0.13')
  return level >= vim.log.get_level(log)
end

--- Convert LSP MessageType to vim.log.levels
---
---@param message_type lsp.MessageType
function M._from_lsp_level(message_type)
  if message_type == protocol.MessageType.Error then
    return log_levels.ERROR
  elseif message_type == protocol.MessageType.Warning then
    return log_levels.WARN
  elseif message_type == protocol.MessageType.Info or message_type == protocol.MessageType.Log then
    return log_levels.INFO
  else
    return log_levels.DEBUG
  end
end

return M
