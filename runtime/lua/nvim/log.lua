-- Thanks to: github.com/rxi/log.lua
-- For the inspiration for a lot of the base of this file

local Enum = require('nvim.meta').Enum

local log = {}
log.__index = log

log.levels = Enum:new({
  debug = 0,
  info  = 1,
  warn  = 2,
  error = 3,
  none = 4,
})

log.set_outfile = function(logger, dir_name, file_name)
  if vim.api.nvim_call_function('isdirectory', {dir_name}) == 0 then
    vim.api.nvim_call_function('mkdir', {dir_name, 'p'})
  end
  logger.outfile = dir_name .. file_name
end

log.set_log_level = function(logger, level)
  logger.log_level = log.levels[level]
end

log.write_file = function(self, level, message)
  local file_pointer = assert(io.open(self.outfile, 'a+'))

  if file_pointer ~= nil then
    local log_message = level .. "\t" .. os.date("%Y-%m-%d %H:%M:%S") .. "\t" .. message .. "\n"
    file_pointer:write(log_message)
    file_pointer:close()
  end

end

log.create_functions = function(new_log, new_logger)
  for name in pairs(log.levels) do
    if log[name] == nil then
      log[name] = function(self, logger, ...)
        if logger.log_level == self.levels['none'] or self.levels[name] < logger.log_level then
          return
        end

        local message = ''
        for _, arg in ipairs({...}) do
          message = message .. require('nvim.util').tostring(arg)
        end

        local info = debug.getinfo(2, "Sl")
        local log_message = string.format(
          "%s:%s\t%s",
          info.short_src,
          info.currentline,
          message
        )

        if self.levels[name] >= logger.log_level then
          log.write_file(logger, name, log_message)
        end
      end
    end
  end

  for key, _ in pairs(log.levels) do
    new_logger[key] = function(...)
      return new_log[key](new_log, new_logger, ...)
    end
  end
end


log.new = function(self, name)
  local new_logger = setmetatable({
    prefix = '[' .. name .. ']'
  }, self)

  self:create_functions(new_logger)

  return new_logger
end

return log
