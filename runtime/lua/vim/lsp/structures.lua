local util = require('vim.lsp.util')
local protocol = require('vim.lsp.protocol')
local server_config = require('vim.lsp.server_config')

-- Helper functions
local check_table = function (t)
  if type(t) ~= 'table' then
    t = {}
  end

  return t
end

-- Structure definitions
local structures = {}

structures.EOL = function()
  if vim.api.nvim_buf_get_option(0, 'eol') then
    return "\n"
  else
    return ''
  end
end

structures.DocumentUri = function(args)
  return args
    or 'file://' .. vim.api.nvim_buf_get_name(0)
end

structures.languageId = function(args)
  return args
     or vim.api.nvim_buf_get_option(0, 'filetype')
end

-- TODO: Increment somehow
local __version = 0
structures.version = function(args)
  __version = __version + 1
  return args
    or __version
end

structures.text = function(args)
  return args
    or util.get_buffer_text(0)
end

structures.TextDocumentIdentifier = function(args)
  args = check_table(args)

  return {
    uri = structures.DocumentUri(args.uri),
  }
end

structures.VersionedTextDocumentIdentifier = function(args)
  args = check_table(args)

  local result = structures.TextDocumentIdentifier(args)
  result.version = structures.version(args.version)

  return result
end

structures.TextDocumentItem = function(args)
  args = check_table(args)

  return {
    uri = structures.DocumentUri(args.uri),
    languageId = structures.languageId(args.languageId),
    version = structures.version(args.version),
    text = structures.text(args.text),
  }
end

structures.line = function(args)
  return args
    -- TODO: Check the conversion of some of these functions from nvim <-> lua
    or (vim.api.nvim_call_function('line', {'.'}) - 1)
end

structures.character = function(args)
  return args
    or (vim.api.nvim_call_function('col', {'.'}) - 1)
end

structures.Position = function(args)
  args = check_table(args)

  return {
    line = structures.line(args.line),
    character = structures.character(args.character),
  }
end

structures.TextDocumentPositionParams = function(args)
  args = check_table(args)

  return {
    textDocument = structures.TextDocumentIdentifier(args.textDocument),
    position = structures.Position(args.position),
  }
end

structures.ReferenceContext = function(args)
  args = check_table(args)

  return {
    includeDeclaration = args.includeDeclaration or true,
  }
end

structures.CompletionContext = function(args)
  args = check_table(args)

  if args.triggerKind == nil and args.triggerCharacter == nil then
    return nil
  end

  return {
    triggerKind = args.triggerKind or nil,
    triggerCharacter = args.triggerCharacter or nil,
  }
end

--- Parameter builder for request method
--

structures.InitializeParams = function(client)
  return {
    processId = vim.api.nvim_call_function('getpid', {}),
    rootUri = server_config.get_root_uri(client.filetype),
    capabilities = {
      textDocument = {
        synchronization = {
          -- TODO(tjdevries): What is this?
          -- dynamicRegistration = false,

          -- Send textDocument/willSave before saving (BufWritePre)
          willSave = true,

          -- TODO(tjdevries): Implement textDocument/willSaveWaitUntil
          willSaveWaitUntil = false,

          -- Send textDocument/didSave after saving (BufWritePost)
          didSave = true,
        },

        -- Capabilities relating to textDocument/completion
        completion = {
          -- TODO(tjdevries): What is this?
          -- dynamicRegistration = false,

          -- base/completionItem
          completionItem = {
            -- TODO(tjdevries): Is it possible to implement this in plain lua?
            snippetSupport = false,

            -- TODO(tjdevries): What is this?
            -- commitCharactersSupport = false,

            -- TODO(tjdevries): What is this?
            documentationFormat = {'plaintext'},
          },

          -- TODO(tjdevries): Handle different completion item kinds differently
          -- completionItemKind = {
          --   valueSet = nil
          -- },

          -- TODO(tjdevries): Implement this
          contextSupport = false,
        },

        -- textDocument/hover
        hover = {
          -- TODO(tjdevries): What is this?
          -- dynamicRegistration = false,

          -- Currently only support plaintext
          --    In the future, if we have floating windows or display in a preview window,
          --    we could say markdown
          contentFormat = {'plaintext'},
        },

        -- textDocument/signatureHelp
        signatureHelp = {
          -- dynamicRegistration = false,

          signatureInformation = {
            documentationFormat = {'plaintext'}
          },
        },

        -- textDocument/references
        -- references = {
        --   dynamicRegistration = nil,
        -- },

        -- textDocument/highlight
        -- documentHighlight = {
        --   dynamicRegistration = nil,
        -- },

        -- textDocument/symbol
        -- TODO(tjdevries): Implement

        -- TODO(tjdevries): Finish these...
      },
    },
  }
end

structures.initializedParams = function(_args)
  return {}
end

structures.CompletionParams = function(args)
  args = check_table(args)

  -- CompletionParams extends TextDocumentPositionParams with an optional context
  local result = structures.TextDocumentPositionParams(args)
  result.context = structures.CompletionContext(args.context)

  return result
end

structures.HoverParams = function(args)
  args = check_table(args)

  return structures.TextDocumentPositionParams(args)
end

structures.SignatureHelpParams = function(args)
  args = check_table(args)

  local params =  structures.TextDocumentPositionParams(args)
  params.position.character = params.position.character + 1

  return params
end

structures.definitionParams = function(args)
  args = check_table(args)

  return structures.TextDocumentPositionParams(args)
end

structures.documentHighlightParams = function(args)
  args = check_table(args)

  return structures.TextDocumentPositionParams(args)
end

structures.ReferenceParams = function(args)
  args = check_table(args)

  local positionParams = structures.TextDocumentPositionParams(args)
  positionParams.context = structures.ReferenceContext(args.context)

  return positionParams
end

structures.RenameParams = function(args)
  args = check_table(args)

  return {
    textDocument = structures.TextDocumentIdentifier(args.textDocument),
    position = structures.Position(args.position),
    newName = args.newName or vim.api.nvim_call_function('inputdialog', { 'New Name: ' }),
  }
end

structures.WorkspaceSymbolParams = function(args)
  args = check_table(args)

  return {
    query = args.query or vim.api.nvim_call_function('expand', { '<cWORD>' })
  }
end

--- Parameter builder for notification method
--

structures.DidOpenTextDocumentParams = function(args)
  args = check_table(args)

  return {
    textDocument = structures.TextDocumentItem(args.textDocument)
  }
end

-- TODO: Incremental changes.
--  Maybe use the PR that externalizes that once its merged
structures.DidChangeTextDocumentParams = function(args)
  args = check_table(args)

  return {
    textDocument = structures.VersionedTextDocumentIdentifier(args.textDocument),
    contentChanges = {
      { text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n") .. structures.EOL() },
    },
  }
end

structures.WillSaveTextDocumentParams = function(args)
  args = check_table(args)

  return {
    textDocument = structures.TextDocumentItem(args.textDocument),
    reason = args.reason or protocol.TextDocumentSaveReason.Manual,
  }
end

structures.DidSaveTextDocumentParams = function(args)
  args = check_table(args)

  return {
    textDocument = structures.TextDocumentItem(args.textDocument),
    text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n") .. structures.EOL(),
  }
end

return structures
