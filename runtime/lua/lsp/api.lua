-- luacheck: globals vim

vim.lsp = {
  plugin = require('lsp.plugin'),
  server_config = {
    add = require('lsp.server_config').add,
  },
  config = require('lsp.config'),
}

return vim.lsp
