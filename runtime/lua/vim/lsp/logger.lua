-- Logger for language client plugin.
-- You can set log levels, debug, info, warn, error and none, like this.
-- let g:language_client_log_level = 'debug'
-- Default value is 'none'.

local Logger = {}
Logger.__index = Logger

Logger.levels = {
  debug = 0,
  info  = 1,
  warn  = 2,
  error = 3,
  none = 4,
}

Logger.set_outfile = function(logger, dir_name, file_name)
  if vim.api.nvim_call_function('isdirectory', {dir_name}) == 0 then
    vim.api.nvim_call_function('mkdir', {dir_name, 'p'})
  end
  logger.outfile = dir_name .. file_name
end

Logger.set_log_level = function(logger, level)
  logger.log_level = Logger.levels[level]
end

Logger.write_file = function(self, level, message)
  local file_pointer = assert(io.open(self.outfile, 'a+'))

  if file_pointer ~= nil then
    local log_message = level .. "\t" .. os.date("%Y-%m-%d %H:%M:%S") .. "\t" .. message .. "\n"
    file_pointer:write(log_message)
    file_pointer:close()
  end

end

Logger.create_functions = function(new_log, new_logger)
  for name in pairs(Logger.levels) do
    if Logger[name] == nil then
      Logger[name] = function(self, logger, ...)
        if logger.log_level == self.levels['none'] or self.levels[name] < logger.log_level then
          return
        end

        local message = ''
        for _, arg in ipairs({...}) do
          message = message .. vim.tbl_tostring(arg)
        end

        local info = debug.getinfo(2, "Sl")
        local log_message = string.format(
          "%s:%s\t%s",
          info.short_src,
          info.currentline,
          message
        )

        if self.levels[name] >= logger.log_level then
          Logger.write_file(logger, name, log_message)
        end
      end
    end
  end

  for key, _ in pairs(Logger.levels) do
    new_logger[key] = function(...)
      return new_log[key](new_log, new_logger, ...)
    end
  end
end

Logger.new = function(self, name)
  local new_logger = setmetatable({
    prefix = '[' .. name .. ']'
  }, self)

  self:create_functions(new_logger)

  return new_logger
end

local logger = Logger:new('LSP')

logger.client = Logger:new('LSP')
logger.server = Logger:new('LSP')

local log_level = 'none'

if (vim.api.nvim_call_function('exists', {'g:language_client_log_level'}) == 1) then
  log_level = vim.api.nvim_get_var('language_client_log_level')
end

logger:set_log_level(log_level)
logger:set_outfile(vim.api.nvim_call_function('stdpath', {'data'})..'/language_client',  '/all.log')

logger.client:set_log_level(log_level)
logger.client:set_outfile(vim.api.nvim_call_function('stdpath', {'data'})..'/language_client',  '/client.log')

logger.server:set_log_level(log_level)
logger.server:set_outfile(vim.api.nvim_call_function('stdpath', {'data'})..'/language_client',  '/server.log')

return logger
