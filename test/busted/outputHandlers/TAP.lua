-- Extends the upstream TAP handler, to display the log with suiteEnd.

local global_helpers = require('test.helpers')

return function(options)
  local busted = require 'busted'
  local handler = require 'busted.outputHandlers.TAP'(options)

  local suiteEnd = function()
    if #handler.failures > 0 or #handler.errors > 0 then
      io.write(global_helpers.read_nvim_log())
    end
    return nil, true
  end
  busted.subscribe({ 'suite', 'end' }, suiteEnd)

  return handler
end
