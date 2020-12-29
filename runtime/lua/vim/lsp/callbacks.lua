local util = require 'vim.lsp.util'

util._warn_once("require('vim.lsp.callbacks') is deprecated. Use vim.lsp.handlers instead.")
return require('vim.lsp.handlers')
