if vim.endswith(vim.fs.normalize(vim.api.nvim_buf_get_name(0)), '/doc/syntax.txt') then
  require('vim.vimhelp').highlight_groups()
end
