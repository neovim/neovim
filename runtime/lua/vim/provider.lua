local M = vim._defer_require('vim.provider', {
  node = ..., --- @module 'vim.provider.node'
  perl = ..., --- @module 'vim.provider.perl'
  python = ..., --- @module 'vim.provider.python'
  ruby = ..., --- @module 'vim.provider.ruby'
})

return M
