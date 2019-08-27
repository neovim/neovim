local util = {
  ui = require('lsp.util.ui'),
}

util.get_buffer_text = function(bufnr)
  return table.concat(util.get_buffer_lines(bufnr), '\n')
end

util.get_buffer_lines = function(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

util.get_filename = function(uri)
  -- TODO: Can't remember if this is the best way
  return string.gsub(uri, 'file://', '')
end

util.get_filetype = function(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  return vim.api.nvim_buf_get_option(bufnr, 'filetype')
end

return util
