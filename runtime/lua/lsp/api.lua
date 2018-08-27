
vim.lsp = {
  client = {
    start = require('lsp.plugin').client.start,
  },
  server = {
    add = require('lsp.server').add,
  },

  config = {
    autocmds  = require('lsp.config.autocmds'),
    callbacks = require('lsp.config.callbacks'),
    log       = require('lsp.config.log'),
    request   = require('lsp.config.request'),
  },
}

return vim.lsp
