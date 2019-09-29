-- Protocol for the Microsoft Language Server Protocol (mslsp)

local util = require('vim.lsp.util')
local server_config = require('vim.lsp.server_config')
local protocol = {}


protocol.DiagnosticSeverity = {
  [1] = 'Error',
  [2] = 'Warning',
  [3] = 'Information',
  [4] = 'Hint',
}

protocol.MessageType = {
  [1] = 'Error',
  [2] = 'Warning',
  [3] = 'Info',
  [4] = 'Log',
}

protocol.FileChangeType = {
  [1] = 'Created',
  [2] = 'Changed',
  [3] = 'Deleted',
}

protocol.CompletionItemKind = {
  [1] = 'Text',
  [2] = 'Method',
  [3] = 'Function',
  [4] = 'Constructor',
  [5] = 'Field',
  [6] = 'Variable',
  [7] = 'Class',
  [8] = 'Interface',
  [9] = 'Module',
  [10] = 'Property',
  [11] = 'Unit',
  [12] = 'Value',
  [13] = 'Enum',
  [14] = 'Keyword',
  [15] = 'Snippet',
  [16] = 'Color',
  [17] = 'File',
  [18] = 'Reference',
  [19] = 'Folder',
  [20] = 'EnumMember',
  [21] = 'Constant',
  [22] = 'Struct',
  [23] = 'Event',
  [24] = 'Operator',
  [25] = 'TypeParameter',
}

protocol.CompletionTriggerKind = {
  [1] = 'Invoked',
  [2] = 'TriggerCharacter',
}

protocol.DocumentHighlightKind = {
  [1] = 'Text',
  [2] = 'Read',
  [3] = 'Write',
}

protocol.SymbolKind = {
  [1] = 'File',
  [2] = 'Module',
  [3] = 'Namespace',
  [4] = 'Package',
  [5] = 'Class',
  [6] = 'Method',
  [7] = 'Property',
  [8] = 'Field',
  [9] = 'Constructor',
  [10] = 'Enum',
  [11] = 'Interface',
  [12] = 'Function',
  [13] = 'Variable',
  [14] = 'Constant',
  [15] = 'String',
  [16] = 'Number',
  [17] = 'Boolean',
  [18] = 'Array',
}

protocol.errorCodes = {
  -- Defined by JSON RPC
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


protocol.TextDocumentSaveReason = {
  [1] = 'Manual',
  [2] = 'AfterDelay',
  [3] = 'FocusOut',
}

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
    or vim.uri_from_bufnr()
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

-- TODO: Not implement workspace features now.
protocol.WorkspaceClientCapabilities = {}
-- {
--   applyEdit = boolean,
--   workspaceEdit = {
--     documentChanges = boolean,
--     resourceOperations = ResourceOperationKind[],
--     failureHandling = FailureHandlingKind,
--   },
--   didChangeConfiguration = {
--     dynamicRegistration = boolean,
--   },
--   didChangeWatchedFiles = {
--     dynamicRegistration = boolean,
--   },
--     symbol = {
--     dynamicRegistration = boolean,
--     symbolKind = {
--       valueSet = SymbolKind[],
--     },
--   },
--   executeCommand = {
--     dynamicRegistration = boolean;
--   },
--   workspaceFolders = boolean,
--   configuration = boolean,
-- }

protocol.TextDocumentClientCapabilities = {
  synchronization = {
    dynamicRegistration = false,

    -- Send textDocument/willSave before saving (BufWritePre)
    willSave = true,

    -- TODO(tjdevries): Implement textDocument/willSaveWaitUntil
    willSaveWaitUntil = false,

    -- Send textDocument/didSave after saving (BufWritePost)
    didSave = true,
  },
  completion = {
    dynamicRegistration = false,
    completionItem = {

      -- TODO(tjdevries): Is it possible to implement this in plain lua?
      snippetSupport = false,
      commitCharactersSupport = false,
      documentationFormat = {'plaintext'},
    },
    completionItemKind = {
      valueSet = vim.tbl_keys(protocol.CompletionItemKind),
    },

    -- TODO(tjdevries): Implement this
    contextSupport = false,
  },
  hover = {
    dynamicRegistration = false,

    -- Currently only support plaintext
    --    In the future, if we have floating windows or display in a preview window,
    --    we could say markdown
    contentFormat = {'plaintext'},
  },
  signatureHelp = {
    dynamicRegistration = false,
    signatureInformation = {
      documentationFormat = {'plaintext'}
    },
  },
  references = {
    dynamicRegistration = false,
  },
  documentHighlight = {
    dynamicRegistration = false
  },
}

protocol.ClientCapabilities = {
  textDocument = protocol.TextDocumentClientCapabilities,
}

--- Parameter builder for request method
--
protocol.InitializeParams = function(client)
  local config = {
    processId = vim.api.nvim_call_function('getpid', {}),
    rootUri = server_config.get_root_uri(client.filetype, client.server_name),
    capabilities = protocol.ClientCapabilities,
  }

  config = vim.tbl_extend('force', config, server_config.get_server_config(client.filetype, client.server_name))
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

protocol.DidCloseTextDocumentParams = function(args)
  args = check_table(args)

  return {
    textDocument = protocol.TextDocumentItem(args.textDocument),
  }
end

return protocol
