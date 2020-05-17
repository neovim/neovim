local TextEdit = require('vim.lsp.structures.text_edit')
local VersionedTextDocumentIdentifier = require('vim.lsp.structures.versioned_text_document_identifier')

---
-- export interface TextDocumentEdit {
--   /**
--    * The text document to change.
--    */
--   textDocument: VersionedTextDocumentIdentifier;
--
--   /**
--    * The edits to be applied.
--    */
--   edits: TextEdit[];
-- }
--
--@ref https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocumentEdit
local TextDocumentEdit = {}

TextDocumentEdit.apply_text_document_edit = function(text_document_edit)
    local text_document = text_document_edit.textDocument
    local bufnr = vim.uri_to_bufnr(text_document.uri)
    if text_document.version then
      local nvim_buf_version = VersionedTextDocumentIdentifier.buf_get_version(bufnr)
      -- `VersionedTextDocumentIdentifier`s version may be null
      --  https://microsoft.github.io/language-server-protocol/specification#versionedTextDocumentIdentifier
      if text_document.version ~= vim.NIL
          and nvim_buf_version ~= nil
          and nvim_buf_version > text_document.version then
        print("Buffer ", text_document.uri, " newer than edits.")
        return
      end
    end

    TextEdit.apply_text_edit(text_document_edit.edits, bufnr)

end

return TextDocumentEdit
