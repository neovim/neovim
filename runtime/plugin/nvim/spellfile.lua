vim.g.loaded_spellfile_plugin = true

--- Callback for SpellFileMissing: download missing .spl
--- @param args { bufnr: integer, match: string }
local function on_spellfile_missing(args)
  vim.spellfile.load_file(args.match)
end

vim.api.nvim_create_autocmd('SpellFileMissing', {
  group = vim.api.nvim_create_augroup('nvim_spellfile', { clear = true }),
  pattern = '*',
  desc = 'Download missing spell files when setting spelllang',
  callback = on_spellfile_missing,
})
