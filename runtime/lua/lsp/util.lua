local lsp_util = {}

lsp_util.get_filetype = function(filetype)
  if not filetype then
    filetype = vim.api.nvim_buf_get_option(0, 'filetype')
  end

  return filetype
end

lsp_util.get_uri = function(filename)
  return 'file://' .. filename
end

lsp_util.get_filename = function(uri)
  -- TODO: Can't remember if this is the best way
  return string.gsub(uri, 'file://', '')
end

lsp_util.get_buffer_lines = function(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

lsp_util.get_buffer_text= function(bufnr)
  return table.concat(lsp_util.get_buffer_lines(bufnr), '\n')
end

return lsp_util
