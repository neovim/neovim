local TextDocumentEdit = require('vim.lsp.structures.text_document_edit')
local TextEdit = require('vim.lsp.structures.text_edit')

--@ref https://microsoft.github.io/language-server-protocol/specifications/specification-current/#workspaceEdit
local WorkspaceEdit = {}

WorkspaceEdit.apply_workspace_edit = function(workspace_edit)
  if workspace_edit.documentChanges then
    for _, change in ipairs(workspace_edit.documentChanges) do
      if change.kind then
        -- TODO(ashkan) handle CreateFile/RenameFile/DeleteFile
        error(string.format("Unsupported change: %q", vim.inspect(change)))
      else
        TextDocumentEdit.apply_text_document_edit(change)
      end
    end
    return
  end

  local all_changes = workspace_edit.changes
  if not all_changes or vim.tbl_isempty(all_changes) then
    return
  end

  for uri, changes in pairs(all_changes) do
    local bufnr = vim.uri_to_bufnr(uri)
    TextEdit.apply_text_edit(changes, bufnr)
  end
end

return WorkspaceEdit
