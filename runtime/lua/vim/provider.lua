---@class vim.provider
---@field perl vim.provider.perl
---@field python vim.provider.python
---@field ruby vim.provider.ruby
local M

M = vim._defer_require('vim.provider', {
  perl = ..., --- @module 'vim.provider.perl'
  python = ..., --- @module 'vim.provider.python'
  ruby = ..., --- @module 'vim.provider.ruby'
})

return M
