local M = vim._defer_require('vim.provider', {
  perl = ..., --- @module 'vim.provider.perl'
  python = ..., --- @module 'vim.provider.python'
  ruby = ..., --- @module 'vim.provider.ruby'
})

return M
