local helpers = require('test.functional.helpers')(after_each)
local eq, clear = helpers.eq, helpers.clear
local missing_provider = helpers.missing_provider

do
  clear()
  if missing_provider('node') then
    pending(
      "Cannot find the neovim node host. Try :checkhealth",
      function() end)
    return
  end
end

before_each(function()
  clear()
end)
