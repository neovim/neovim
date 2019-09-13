local TextDocument = {}


--- Apply the TextDocumentEdit response.
-- @params TextDocumentEdit [table] see https://microsoft.github.io/language-server-protocol/specification
TextDocument.apply_TextDocumentEdit = function(TextDocumentEdit)
  local text_document = TextDocumentEdit.textDocument

  for _, TextEdit in ipairs(TextDocumentEdit.edits) do
    TextDocument.apply_TextEdit(text_document, TextEdit)
  end
end

--- Apply the TextEdit response.
-- @params TextEdit [table] see https://microsoft.github.io/language-server-protocol/specification
TextDocument.apply_TextEdit = function(TextEdit)
  local range = TextEdit.range

  local range_start = range['start']
  local range_end = range['end']

  local new_text = TextEdit.newText

  if range_start.character ~= 0 or range_end.character ~= 0 then
    vim.api.nvim_err_writeln('apply_TextEdit currently only supports character ranges starting at 0')
    return
  end

  vim.api.nvim_buf_set_lines(0, range_start.line, range_end.line, false, vim.split(new_text, "\n", true))
end

return TextDocument
