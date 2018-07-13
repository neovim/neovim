
vim.lsp = {
  server = {
    add = require('lsp.server').add,
  },

  config = {
    callbacks = require('lsp.config.callbacks'),
    request = require('lsp.config.request'),
    log = require('lsp.config.log'),
  },
}

return vim.lsp
