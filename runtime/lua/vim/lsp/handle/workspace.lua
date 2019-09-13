local TextDocument = require('vim.lsp.handle.text_document')

local Workspace = {}

-- @params WorkspaceEdit [table] see https://microsoft.github.io/language-server-protocol/specification
Workspace.apply_WorkspaceEdit = function(WorkspaceEdit)
  if WorkspaceEdit.documentChanges ~= nil then
    for _, textDocumentEdit in ipairs(WorkspaceEdit.documentChanges) do
      TextDocument.apply_TextDocumentEdit(textDocumentEdit)
    end

    return
  end

  -- TODO: handle (deprecated) changes
  local changes = WorkspaceEdit.changes

  if changes == nil or #changes == 0 then
    return
  end

end

return Workspace
