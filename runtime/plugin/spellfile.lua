vim.api.nvim_create_autocmd('SpellFileMissing', {
  callback = function(args)
    local lang = vim.bo[args.bufnr].spelllang
    require('spellfile').load_file(lang)
  end,
})
