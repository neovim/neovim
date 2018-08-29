
local util = require('neovim.util')

local textDocument = {}

textDocument.apply_TextEdits = function(TextDocumentEdit)
  local text_document = TextDocumentEdit.textDocument

  for _, TextEdit in ipairs(TextDocumentEdit.edits) do
    textDocument.apply_TextEdit(text_document, TextEdit)
  end
end

textDocument.apply_TextEdit = function(VersionedTextDocumentIdentifier, TextEdit)
  local range = TextEdit.range

  local range_start = range['start']
  local range_end = range['end']

  local new_text = TextEdit.newText

  if range_start.character ~= 0 or range_end.character ~= 0 then
    vim.api.nvim_err_writeln('apply_TextEdit currently only supports character ranges starting at 0')
    return
  end

  vim.api.nvim_buf_set_lines(0, range_start.line, range_end.line, false, util.split(new_text, "\n"))
end

return textDocument
