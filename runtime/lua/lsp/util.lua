local util = require('nvim.util')

local lsp_util = {}

lsp_util.get_filetype = function(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  return vim.api.nvim_buf_get_option(bufnr, 'filetype')
end

lsp_util.get_uri = function(location)
  if location then
    return 'file://' .. location
  else
    return ''
  end
end


lsp_util.get_filename = function(uri)
  -- TODO: Can't remember if this is the best way
  return string.gsub(uri, 'file://', '')
end

lsp_util.get_buffer_lines = function(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

lsp_util.get_buffer_text = function(bufnr)
  return table.concat(lsp_util.get_buffer_lines(bufnr), '\n')
end

lsp_util.get_line_from_path = function(path, line_number)
  local buf_number = vim.api.nvim_call_function('bufnr', { path })
  local text

  if buf_number == -1 then
    text = util.get_file_line(path, line_number)
  else
    text = vim.api.nvim_buf_get_lines(buf_number, line_number - 1, line_number, false)[1]
  end

  if text == nil then
    text = ''
  end

  return text
end

-- Line position in a document (zero-based).
lsp_util.get_line = function()
  return vim.api.nvim_call_function('line', { '.' }) - 1
end

-- Character offset on a line in a document (zero-based). Assuming that the line is
-- represented as a string, the `character` value represents the gap between the
-- `character` and `character + 1`.
-- If the character value is greater than the line length it defaults back to the
-- line length.
lsp_util.get_character = function()
  return vim.api.nvim_call_function('col', { '.' }) - 1
end

lsp_util.get_position = function()
  return {line = lsp_util.get_line(), character = lsp_util.get_character()}
end

-- Text documents are identified using a URI.
-- On the protocol level, URIs are passed as strings.
-- The corresponding JSON structure.
lsp_util.get_text_document_identifier = function()
  local filename = vim.api.nvim_call_function('expand', { '<afile>:p' })
  if not filename then
    filename = vim.api.nvim_call_function('expand', { '%:p' })
  end
  return { url = filename }
end

lsp_util.get_buffer_uri = function(bufnr)
  local location
  if bufnr then
     location = vim.api.nvim_command("echo expand('#" .. bufnr .. ":p')")
  else
    location = vim.api.nvim_command("echo expand('%" .. ":p')")
  end
  return lsp_util.get_uri(location)
end

lsp_util.get_text_document_params = function()
  return {
    textDocument = lsp_util.get_text_document_identifier(),
    position = lsp_util.get_position(),
  }
end

return lsp_util
