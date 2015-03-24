-- busted output handler that immediately prints file and test names before
-- tests are executed. It simplifies identifying which tests are
-- hanging/crashing
if package.config:sub(1,1) == '\\' and not os.getenv("ANSICON") then
  -- Disable colors on Windows.
  colors = setmetatable({}, {__index = function() return function(s) return s end end})
else
  colors = require 'term.colors'
end

return function(options, busted)
  local handler = require 'busted.outputHandlers.utfTerminal'(options, busted)

  handler.fileStart = function(name)
    io.write('\n' .. colors.cyan(name) .. ':')
  end

  handler.testStart = function(element, parent, status, debug)
    io.write('\n  ' .. handler.getFullName(element) .. ' ... ')
    io.flush()
  end

  busted.subscribe({ 'file', 'start' }, handler.fileStart)
  busted.subscribe({ 'test', 'start' }, handler.testStart)

  return handler
end
