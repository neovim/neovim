local util = require('vim.lsp.util')

local TextDocumentIdentifier = {}

TextDocumentIdentifier.to_bufnr = function(text_document_identifier, should_load)
  local bufnr = vim.uri_from_bufnr(text_document_identifier.uri)

  should_load = util.if_nil(should_load, true)
  if should_load and not vim.api.nvim_buf_is_loaded(bufnr) then
    vim.fn.bufload(bufnr)
  end

  return bufnr
end

return TextDocumentIdentifier
