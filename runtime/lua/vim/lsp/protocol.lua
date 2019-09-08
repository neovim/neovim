-- Protocol for the Microsoft Language Server Protocol (mslsp)

local Enum = require('vim.lsp.util').Enum
local util = require('vim.lsp.util')
local server_config = require('vim.lsp.server_config')
local protocol = {}


protocol.DiagnosticSeverity = Enum:new({
  Error = 1,
  Warning = 2,
  Information = 3,
  Hint = 4
})

protocol.MessageType = Enum:new({
  Error = 1,
  Warning = 2,
  Info = 3,
  Log = 4
})

protocol.FileChangeType = Enum:new({
    Created = 1,
    Changed = 2,
    Deleted = 3
})

protocol.CompletionItemKind = {
    'Text',
    'Method',
    'Function',
    'Constructor',
    'Field',
    'Variable',
    'Class',
    'Interface',
    'Module',
    'Property',
    'Unit',
    'Value',
    'Enum',
    'Keyword',
    'Snippet',
    'Color',
    'File',
    'Reference',
    'Folder',
    'EnumMember',
    'Constant',
    'Struct',
    'Event',
    'Operator',
    'TypeParameter',
}

protocol.CompletionTriggerKind = Enum:new({
  Invoked = 1,
  TriggerCharacter = 2,
})

protocol.DocumentHighlightKind = Enum:new({
    Text = 1,
    Read = 2,
    Write = 3
})

protocol.SymbolKind = Enum:new({
    File = 1,
    Module = 2,
    Namespace = 3,
    Package = 4,
    Class = 5,
    Method = 6,
    Property = 7,
    Field = 8,
    Constructor = 9,
    Enum = 10,
    Interface = 11,
    Function = 12,
    Variable = 13,
    Constant = 14,
    String = 15,
    Number = 16,
    Boolean = 17,
    Array = 18,
})

protocol.errorCodes = {
  [-32700] = 'Parse error',
  [-32600] = 'Invalid Request',
  [-32601] = 'Method not found',
  [-32602] = 'Invalid params',
  [-32603] = 'Internal error',
  [-32099] = 'Server Error Start',
  [-32000] = 'Server Error End',
  [-32002] = 'Server Not Initialized',
  [-32001] = 'Unknown Error Code',
  -- Defined by the protocol
  [-32800] = 'Request Cancelled',
}


protocol.TextDocumentSaveReason = Enum:new({
  Manual = 1,
  AfterDelay = 2,
  FocusOut = 3,
})

-- Helper functions
local check_table = function (t)
  if type(t) ~= 'table' then
    t = {}
  end

  return t
end

protocol.EOL = function()
  if vim.api.nvim_buf_get_option(0, 'eol') then
    return "\n"
  else
    return ''
  end
end

protocol.DocumentUri = function(args)
  return args
    or 'file://' .. vim.api.nvim_buf_get_name(0)
end

protocol.languageId = function(args)
  return args
     or vim.api.nvim_buf_get_option(0, 'filetype')
end

-- TODO: Increment somehow
local __version = 0
protocol.version = function(args)
  __version = __version + 1
  return args
    or __version
end

protocol.text = function(args)
  return args
    or util.get_buffer_text(0)
end

protocol.TextDocumentIdentifier = function(args)
  args = check_table(args)

  return {
    uri = protocol.DocumentUri(args.uri),
  }
end

protocol.VersionedTextDocumentIdentifier = function(args)
  args = check_table(args)

  local identifier = protocol.TextDocumentIdentifier(args)
  identifier.version = protocol.version(args.version)

  return identifier
end

protocol.TextDocumentItem = function(args)
  args = check_table(args)

  return {
    uri = protocol.DocumentUri(args.uri),
    languageId = protocol.languageId(args.languageId),
    version = protocol.version(args.version),
    text = protocol.text(args.text),
  }
end

protocol.line = function(args)
  return args
    -- TODO: Check the conversion of some of these functions from nvim <-> lua
    or (vim.api.nvim_call_function('line', {'.'}) - 1)
end

protocol.character = function(args)
  return args
    or (vim.api.nvim_call_function('col', {'.'}) - 1)
end

protocol.Position = function(args)
  args = check_table(args)

  return {
    line = protocol.line(args.line),
    character = protocol.character(args.character),
  }
end

protocol.TextDocumentPositionParams = function(args)
  args = check_table(args)

  return {
    textDocument = protocol.TextDocumentIdentifier(args.textDocument),
    position = protocol.Position(args.position),
  }
end

protocol.ReferenceContext = function(args)
  args = check_table(args)

  return {
    includeDeclaration = args.includeDeclaration or true,
  }
end

protocol.CompletionContext = function(args)
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

protocol.InitializeParams = function(client)
  local config = {
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

  config = vim.tbl_extend('force', config, server_config.get_server_config(client.filetype))
  client:set_client_capabilities(config)
  return config
end

protocol.initializedParams = function(_args)
  return {}
end

protocol.CompletionParams = function(args)
  args = check_table(args)

  -- CompletionParams extends TextDocumentPositionParams with an optional context
  local result = protocol.TextDocumentPositionParams(args)
  result.context = protocol.CompletionContext(args.context)

  return result
end

protocol.HoverParams = function(args)
  args = check_table(args)

  return protocol.TextDocumentPositionParams(args)
end

protocol.SignatureHelpParams = function(args)
  args = check_table(args)

  local position =  protocol.TextDocumentPositionParams(args)
  position.position.character = position.position.character + 1

  return position
end

protocol.definitionParams = function(args)
  args = check_table(args)

  return protocol.TextDocumentPositionParams(args)
end

protocol.documentHighlightParams = function(args)
  args = check_table(args)

  return protocol.TextDocumentPositionParams(args)
end

protocol.ReferenceParams = function(args)
  args = check_table(args)

  local position = protocol.TextDocumentPositionParams(args)
  position.context = protocol.ReferenceContext(args.context)

  return position
end

protocol.RenameParams = function(args)
  args = check_table(args)

  return {
    textDocument = protocol.TextDocumentIdentifier(args.textDocument),
    position = protocol.Position(args.position),
    newName = args.newName or vim.api.nvim_call_function('inputdialog', { 'New Name: ' }),
  }
end

protocol.WorkspaceSymbolParams = function(args)
  args = check_table(args)

  return {
    query = args.query or vim.api.nvim_call_function('expand', { '<cWORD>' })
  }
end

--- Parameter builder for notification method
--

protocol.DidOpenTextDocumentParams = function(args)
  args = check_table(args)

  return {
    textDocument = protocol.TextDocumentItem(args.textDocument)
  }
end

-- TODO: Incremental changes.
--  Maybe use the PR that externalizes that once its merged
protocol.DidChangeTextDocumentParams = function(args)
  args = check_table(args)

  return {
    textDocument = protocol.VersionedTextDocumentIdentifier(args.textDocument),
    contentChanges = {
      { text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n") .. protocol.EOL() },
    },
  }
end

protocol.WillSaveTextDocumentParams = function(args)
  args = check_table(args)

  return {
    textDocument = protocol.TextDocumentItem(args.textDocument),
    reason = args.reason or protocol.TextDocumentSaveReason.Manual,
  }
end

protocol.DidSaveTextDocumentParams = function(args)
  args = check_table(args)

  return {
    textDocument = protocol.TextDocumentItem(args.textDocument),
    text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n") .. protocol.EOL(),
  }
end

return protocol
