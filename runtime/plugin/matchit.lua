if vim.g.loaded_matchit_plugin ~= nil then
  return
end
vim.g.loaded_matchit_plugin = true


vim.keymap.set("n", "H", function ()
  require('matchit').decide()
end)

vim.keymap.set("n", "%H", function ()
  require('matchit').decide(true)
end)
