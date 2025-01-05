if vim.g.loaded_matchpairs_plugin ~= nil then
  return
end
vim.g.loaded_matchpairs_plugin = true


vim.keymap.set('n', 'H', function()
  require('vim._matchpairs').decide()
end)

vim.keymap.set('n', '%H', function()
  require('vim._matchpairs').decide(true)
end)

vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI', 'WinEnter' }, {
  callback = function()
    require('vim._matchpairs').highlight()
  end
})
