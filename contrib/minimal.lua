local minimal_path = vim.fn.stdpath 'cache' .. '/test-minimal-config/site'

vim.cmd [[set runtimepath=$VIMRUNTIME]]
vim.cmd('set packpath=' .. minimal_path)

_G.load_config = function()
  -- ADD INIT.LUA SETTINGS THAT ARE _NECESSARY_ FOR REPRODUCING THE ISSUE
end

local function load_plugins()
  require('packer').startup {
    {
      'wbthomason/packer.nvim',
      -- ADD PLUGINS THAT ARE _NECESSARY_ FOR REPRODUCING THE ISSUE
    },
    config = {
      package_root = minimal_path .. '/pack',
      compile_path = minimal_path .. '/pack/_loader/start/_load/plugin/packer_compiled.lua',
      display = { non_interactive = true },
    },
  }
end

local install_path = minimal_path .. '/pack/packer/start/packer.nvim'
if vim.fn.isdirectory(install_path) == 0 then
  vim.fn.system { 'git', 'clone', '--depth=1', 'git://github.com/wbthomason/packer.nvim', install_path }
end
load_plugins()
require('packer').sync()
vim.cmd [[autocmd User PackerComplete ++once echo "Ready!" | lua load_config()]]
