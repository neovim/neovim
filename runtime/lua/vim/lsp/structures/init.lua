--[[

structures.lua

structures is the location to put the handling of any of the structures as defined by
the language server protocol.

Naming scheme:
- If a function begins with one of the neovim API primitives (buf, win, tab, etc.)
  then the first argument of the function must be that primitive.

  For example, Diagnostic.buf_clear_displayed_diagnostics(...) must have `bufnr`
  as its first argument.

- Otherwise, any function defined on a structure must take as the first argument
  the structure itself and then any optional parameters required for determining
  the behavior.

  For example, all `Location.*` must be a function of the form:

    function(location, ...)

TODO(tjdevries): Determine if this is the right place to put this.
Function interface:
  - Functions that do not succeed, either via invalid parameters or unable to complete
    must return false. Optionally, they can return a message as the second return value.

Additionally, within each `structure.*`, they can import only directly from other structures using:

  require('vim.lsp.structures.location')

Rather than:

  require('vim.lsp.structures').location


However, from the rest of the project, they should be imported in the latter style.

--]]

local structures = {}

structures.Diagnostic = require('vim.lsp.structures.diagnostic')
structures.Location = require('vim.lsp.structures.location')
structures.Position = require('vim.lsp.structures.position')
structures.TextDocumentEdit = require('vim.lsp.structures.text_document_edit')
structures.TextDocumentIdentifier = require('vim.lsp.structures.text_document_identifier')
structures.TextEdit = require('vim.lsp.structures.text_edit')
structures.VersionedTextDocumentIdentifier = require('vim.lsp.structures.versioned_text_document_identifier')
structures.WorkspaceEdit = require('vim.lsp.structures.workspace_edit')

return structures
