local group = vim.api.nvim_create_augroup('editorconfig', {})
vim.api.nvim_create_autocmd({ 'BufNewFile', 'BufRead', 'BufFilePost' }, {
  group = group,
  callback = function(args)
    -- Buffer-local enable has higher priority
    local enable = vim.F.if_nil(vim.b.editorconfig, vim.g.editorconfig, true)
    if not enable then
      return
    end

    require('editorconfig').config(args.buf)
  end,
})
