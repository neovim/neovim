-- Thanks to: github.com/rxi/log.lua
-- For the inspiration for a lot of the base of this file

local Enum = require('neovim.meta').Enum

local log = {}
log.__index = log

log.levels = Enum:new({
  bad_level = 0,
  trace = 1,
  debug = 2,
  info  = 3,
  warn  = 4,
  ['error'] = 5,
  fatal = 6,
})


log.set_outfile = function(logger, file_name)
  -- TODO(tjdevries): Check that it's a valid file path
  logger.outfile = file_name
end

log.set_console_level = function(logger, level)
  logger.console_level = log.levels[level]
end

log.set_file_level = function(logger, level)
  logger.file_level = log.levels[level]
end

log.write_file = function(self, level, message)
  local file_pointer = assert(io.open(self.outfile, 'a+'))

  if file_pointer ~= nil then
    local log_message = message .. "\n"
    file_pointer:write(log_message)
    file_pointer:close()
  end

end

log.create_functions = function(new_log, new_logger)
  for name in pairs(log.levels) do
    if log[name] == nil then
      log[name] = function(self, logger, ...)
        -- If both levels are too high, just quit
        if self.levels[name] < logger.console_level and
            self.levels[name] < logger.file_level then

          return
        end

        local message = ''
        for _, arg in ipairs({...}) do
          message = message .. require('neovim.util').tostring(arg)
        end

        local info = debug.getinfo(2, "Sl")
        local log_message = string.format("<< [%-6s%s] %s:%-4s >>\n      %s %s",
          name,
          os.date("%H:%M:%S"),
          info.short_src,
          info.currentline,
          logger.prefix,
          message)

        if self.levels[name] >= logger.file_level then
          log.write_file(logger, name, log_message)
        end

        if self.levels[name] >= logger.console_level then
          print(log_message .. "\n")
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
