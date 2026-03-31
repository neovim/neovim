if vim.g.loaded_spellfile_plugin ~= nil then
  return
end
vim.g.loaded_spellfile_plugin = true

vim.api.nvim_create_autocmd('SpellFileMissing', {
  group = vim.api.nvim_create_augroup('nvim.spellfile', {}),
  desc = 'Download missing spell files when setting spelllang',
  callback = function(args)
    require('nvim.spellfile').get(args.match)
  end,
})
