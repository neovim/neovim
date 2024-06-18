if vim.g.loaded_spellfile_plugin ~= nil or vim.fn.exists('#SpellFileMissing') == 1 then
  return
end
vim.g.loaded_spellfile_plugin = true

vim.api.nvim_create_autocmd('SpellFileMissing', {
  pattern = '*',
  callback = function(args)
    require 'spellfile'.download_spell(args.match)
  end,
})
