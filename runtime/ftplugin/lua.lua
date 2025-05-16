---@param name string
---@param value any
local function set_local_default(name, value)
  if
    vim.api.nvim_get_option_value(name, { scope = 'global' })
    == vim.api.nvim_get_option_info2(name, { scope = 'global' }).default
  then
    vim.api.nvim_set_option_value(name, value, { scope = 'local' })
  end
end

-- use treesitter over syntax
vim.treesitter.start()

vim.bo.includeexpr = [[v:lua.require'vim._ftplugin.lua'.includeexpr(v:fname)]]
vim.bo.omnifunc = 'v:lua.vim.lua_omnifunc'
set_local_default('foldexpr', 'v:lua.vim.treesitter.foldexpr()')

vim.b.undo_ftplugin = (vim.b.undo_ftplugin or '')
  .. '\n call v:lua.vim.treesitter.stop()'
  .. '\n setl omnifunc< foldexpr< includeexpr<'
