-- TODO(tjdevries): Change over logging within LSP to this.
-- TODO(tjdevries): Create a better logging interface, so if other plugins want to use this, they can.
--  Maybe even make a few vimL wrapper functions.
--  Maybe make a remote function

local neovim_log = require('neovim.log')

local log = setmetatable({}, {
  __index = neovim_log,
})

log.prefix = '[LSP]'

for key, _ in pairs(neovim_log.levels) do
  log[key] = function(...)
    return log[key](log.prefix, ...)
  end
end

return log

