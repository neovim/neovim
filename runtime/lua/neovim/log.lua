local log = {}

log.levels = {
  bad_level = 0,
  trace = 1,
  debug = 2,
  info  = 3,
  warn  = 4,
  ['error'] = 5,
  fatal = 6,
}

log.console_level = 'warn'
log.file_level = 'warn'
log.prefix = ''
log.outfile = vim.api.nvim_call_function('expand', {'~'}) .. '/test_logfile.txt'

log.write_file = function(level, message)
  if log.levels[level] < log.levels[log.file_level] then
    return
  end

  local file_pointer = assert(io.open(log.outfile, 'a+'))

  if file_pointer ~= nil then
    local log_message = message .. "\n"
    file_pointer:write(log_message)
    file_pointer:close()
  end

end

-- TODO: Check github.com/rxi/log.lua

for name in pairs(log.levels) do
  log[name] = function(...)
    local message = ''
    for _, arg in ipairs({...}) do
      message = message .. require('neovim.util').tostring(arg)
    end

    local info = debug.getinfo(2, "Sl")
    local log_message = string.format("[%-6s%s] %s:%-4s: %s %s",
      name,
      os.date("%H:%M:%S"),
      info.short_src,
      info.currentline,
      log.prefix,
      message)

    log.write_file(name, log_message)

    -- TODO: Error here instead?
    -- Only log messages with applicable levels
    if log.levels[name] > log.levels[log.console_level] then

      if vim ~= nil and vim.api ~= nil then
        -- vim.api.nvim_command([[echom ']] .. log_message .. [[']])
        print(log_message .. "\n")
      else
        print(log_message .. "\n")
      end
    end
  end
end

return log
