-- luacheck: globals vim

vim.lsp = {
  plugin = require('lsp.plugin'),
  server_config = require('lsp.server_config'),
  config = require('lsp.config'),
  structures = require('lsp.structures'),
  util = require('lsp.util'),
}

return vim.lsp
