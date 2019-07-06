-- luacheck: globals vim

vim.lsp = {
  client = require('lsp.plugin').client,
  server = {
    add = require('lsp.server').add,
  },
  config = require('lsp.config'),
}

return vim.lsp
