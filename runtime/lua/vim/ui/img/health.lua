local M = {}
local health = vim.health

function M.check()
  health.start('vim.ui.img')

  local supported, msg = require('vim.ui.img')._supported()

  if supported then
    if msg then
      health.ok(('Graphics protocol: supported (%s)'):format(msg))
    else
      health.ok('Graphics protocol: supported')
    end
  else
    health.error('Graphics protocol: not supported by this terminal.')
  end

  if vim.env.TMUX then
    health.warn('tmux is detected. Images may not display correctly.')
  end
end

return M
