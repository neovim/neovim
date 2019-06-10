local nvim_eval = vim.api.nvim_eval

local new_plugin = require('helpers.plugin').new_plugin

if not vim.helpers then vim.helpers = {} end

vim.helpers.new_plugin = new_plugin

local module ={
  new_plugin = new_plugin,
}

return module
