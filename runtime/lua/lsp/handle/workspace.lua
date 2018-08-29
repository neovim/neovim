
local textDocument = require('lsp.handle.textDocument')

local workspace = {}

workspace.apply_WorkspaceEdit = function(WorkspaceEdit)
  if WorkspaceEdit.documentChanges ~= nil then
    for _, textDocumentEdit in ipairs(WorkspaceEdit.documentChanges) do
      textDocument.apply_TextEdits(textDocumentEdit)
    end

    return
  end

  -- TODO: handle (deprecated) changes
  local changes = WorkspaceEdit.changes

  if changes == nil or #changes == 0 then
    return
  end

end

return workspace
