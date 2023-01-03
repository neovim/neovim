if vim.g.editorconfig_enable == false or vim.g.editorconfig_enable == 0 then
  return
end

local group = vim.api.nvim_create_augroup('editorconfig', {})
vim.api.nvim_create_autocmd({ 'BufNewFile', 'BufRead', 'BufFilePost' }, {
  group = group,
  callback = function(args)
    require('editorconfig').config(args.buf)
  end,
})
