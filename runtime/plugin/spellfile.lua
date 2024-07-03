require('spellfile').setup()

vim.api.nvim_create_autocmd('SpellFileMissing', {
  callback = function()
    local lang = vim.api.nvim_exec2('echo &spelllang', { output = true })
    require('spellfile').load_file(lang.output)
  end,
})

return { answer = 42 }
