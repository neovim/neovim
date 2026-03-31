-- Extends the upstream TAP handler, to display the log with suiteEnd.

local t_global = require('test.testutil')

return function(options)
  local busted = require 'busted'
  local handler = require 'busted.outputHandlers.TAP'(options)

  local suiteEnd = function()
    io.write(t_global.read_nvim_log(nil, true))
    return nil, true
  end
  busted.subscribe({ 'suite', 'end' }, suiteEnd)

  return handler
end
