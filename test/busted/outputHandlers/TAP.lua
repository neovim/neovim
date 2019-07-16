-- Extends the upstream TAP handler, to display the log with suiteEnd.

local global_helpers = require('test.helpers')

return function(options)
  local handler = require 'busted.outputHandlers.TAP'(options)

  handler.suiteEnd = function()
    io.write(global_helpers.read_nvim_log())
    return handler.suiteEnd()
  end

  return handler
end
