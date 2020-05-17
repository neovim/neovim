local TextDocumentIdentifier = require('vim.lsp.structures.text_document_identifier')

--- Versioned Text Document Identifier extends |TextDocumentIdentifier|
--
--@ref https://microsoft.github.io/language-server-protocol/specifications/specification-current/#versionedTextDocumentIdentifier
local VersionedTextDocumentIdentifier = setmetatable({}, {__index = TextDocumentIdentifier})

local buf_versions = {}

--- Get the current version for the buffer.
VersionedTextDocumentIdentifier.buf_get_version = function(bufnr)
  if bufnr == 0 then bufnr = vim.api.nvim_get_current_buf() end

  return buf_versions[bufnr] or 0
end

--- Set the version for the buffer.
VersionedTextDocumentIdentifier.buf_set_version = function(bufnr, version)
  if bufnr == 0 then bufnr = vim.api.nvim_get_current_buf() end

  buf_versions[bufnr] = version
end

return VersionedTextDocumentIdentifier
