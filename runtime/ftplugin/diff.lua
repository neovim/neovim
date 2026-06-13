if vim.nonnil(vim.b.diffhl, vim.g.diffhl, true) then
  require('nvim.diffhl').attach(0)
  vim.b.undo_ftplugin = (vim.b.undo_ftplugin or '')
    .. "\n call v:lua.require'nvim.diffhl'.detach(0)"
end
