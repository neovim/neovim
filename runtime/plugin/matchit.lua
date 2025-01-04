if vim.g.loaded_matchit_plugin ~= nil then
  return
end
vim.g.loaded_matchit_plugin = true


vim.keymap.set('n', 'H', function()
  require('matchit').decide()
end)

vim.keymap.set('n', '%H', function()
  require('matchit').decide(true)
end)

vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI', 'WinEnter' }, {
  callback = function()
    require('matchit').highlight()
  end
})
