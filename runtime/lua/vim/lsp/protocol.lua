-- Protocol for the Microsoft Language Server Protocol (mslsp)

local server_config = require('vim.lsp.server_config')
local protocol = {}

-- Useful for interfacing with:
-- https://github.com/microsoft/language-server-protocol/blob/gh-pages/_specifications/specification-3-14.md
-- function transform_schema_to_table()
-- 	nvim.command [[silent! '<,'>g/\/\*\*\|\*\/\|^$/d]]
-- 	nvim.command [[silent! '<,'>s/^\s*\*\(.*\)/  --\1/]]
-- 	nvim.command [[silent! '<,'>s/: \S\+//]]
-- 	nvim.command [[silent! '<,'>s/export const //]]
-- 	nvim.command [[silent! '<,'>s/export namespace \(\S*\)\s*{/protocol.\1 = {/]]
-- 	nvim.command [[silent! '<,'>s/namespace \(\S*\)\s*{/protocol.\1 = {/]]
-- end

local function add_reverse_lookup(o)
	local keys = {}
	for k in pairs(o) do table.insert(keys, k) end
	for _, k in ipairs(keys) do o[o[k]] = k end
	return o
end

local constants = {
	DiagnosticSeverity = {
		-- Reports an error.
		Error = 1;
		-- Reports a warning.
		Warning = 2;
		-- Reports an information.
		Information = 3;
		-- Reports a hint.
		Hint = 4;
	};

	MessageType = {
		-- An error message.
		Error = 1;
		-- A warning message.
		Warning = 2;
		-- An information message.
		Info = 3;
		-- A log message.
		Log = 4;
	};

	-- The file event type.
	FileChangeType = {
		-- The file got created.
		Created = 1;
		-- The file got changed.
		Changed = 2;
		-- The file got deleted.
		Deleted = 3;
	};

	-- The kind of a completion entry.
	CompletionItemKind = {
		Text = 1;
		Method = 2;
		Function = 3;
		Constructor = 4;
		Field = 5;
		Variable = 6;
		Class = 7;
		Interface = 8;
		Module = 9;
		Property = 10;
		Unit = 11;
		Value = 12;
		Enum = 13;
		Keyword = 14;
		Snippet = 15;
		Color = 16;
		File = 17;
		Reference = 18;
		Folder = 19;
		EnumMember = 20;
		Constant = 21;
		Struct = 22;
		Event = 23;
		Operator = 24;
		TypeParameter = 25;
	};

	-- How a completion was triggered
	CompletionTriggerKind = {
		-- Completion was triggered by typing an identifier (24x7 code
		-- complete), manual invocation (e.g Ctrl+Space) or via API.
		Invoked = 1;
		-- Completion was triggered by a trigger character specified by
		-- the `triggerCharacters` properties of the `CompletionRegistrationOptions`.
		TriggerCharacter = 2;
		-- Completion was re-triggered as the current completion list is incomplete.
		TriggerForIncompleteCompletions = 3;
	};

	-- A document highlight kind.
	DocumentHighlightKind = {
		-- A textual occurrence.
		Text = 1;
		-- Read-access of a symbol, like reading a variable.
		Read = 2;
		-- Write-access of a symbol, like writing to a variable.
		Write = 3;
	};

	-- A symbol kind.
	SymbolKind = {
		File = 1;
		Module = 2;
		Namespace = 3;
		Package = 4;
		Class = 5;
		Method = 6;
		Property = 7;
		Field = 8;
		Constructor = 9;
		Enum = 10;
		Interface = 11;
		Function = 12;
		Variable = 13;
		Constant = 14;
		String = 15;
		Number = 16;
		Boolean = 17;
		Array = 18;
		Object = 19;
		Key = 20;
		Null = 21;
		EnumMember = 22;
		Struct = 23;
		Event = 24;
		Operator = 25;
		TypeParameter = 26;
	};

	-- Represents reasons why a text document is saved.
	TextDocumentSaveReason = {
		-- Manually triggered, e.g. by the user pressing save, by starting debugging,
		-- or by an API call.
		Manual = 1;
		-- Automatic after a delay.
		AfterDelay = 2;
		-- When the editor lost focus.
		FocusOut = 3;
	};

	ErrorCodes = {
		-- Defined by JSON RPC
		ParseError           = -32700;
		InvalidRequest       = -32600;
		MethodNotFound       = -32601;
		InvalidParams        = -32602;
		InternalError        = -32603;
		serverErrorStart     = -32099;
		serverErrorEnd       = -32000;
		ServerNotInitialized = -32002;
		UnknownErrorCode     = -32001;
		-- Defined by the protocol.
		RequestCancelled     = -32800;
		ContentModified      = -32801;
	};

	-- Describes the content type that a client supports in various
	-- result literals like `Hover`, `ParameterInfo` or `CompletionItem`.
	--
	-- Please note that `MarkupKinds` must not start with a `$`. This kinds
	-- are reserved for internal usage.
	MarkupKind = {
		-- Plain text is supported as a content format
		PlainText = 'plaintext';
		-- Markdown is supported as a content format
		Markdown = 'markdown';
	};

	ResourceOperationKind = {
		-- Supports creating new files and folders.
		Create = 'create';
		-- Supports renaming existing files and folders.
		Rename = 'rename';
		-- Supports deleting existing files and folders.
		Delete = 'delete';
	};

	FailureHandlingKind = {
		-- Applying the workspace change is simply aborted if one of the changes provided
		-- fails. All operations executed before the failing operation stay executed.
		Abort = 'abort';
		-- All operations are executed transactionally. That means they either all
		-- succeed or no changes at all are applied to the workspace.
		Transactional = 'transactional';
		-- If the workspace edit contains only textual file changes they are executed transactionally.
		-- If resource changes (create, rename or delete file) are part of the change the failure
		-- handling strategy is abort.
		TextOnlyTransactional = 'textOnlyTransactional';
		-- The client tries to undo the operations already executed. But there is no
		-- guarantee that this succeeds.
		Undo = 'undo';
	};

	-- Known error codes for an `InitializeError`;
	InitializeError = {
		-- If the protocol version provided by the client can't be handled by the server.
		-- @deprecated This initialize error got replaced by client capabilities. There is
		-- no version handshake in version 3.0x
		unknownProtocolVersion = 1;
	};

	-- Defines how the host (editor) should sync document changes to the language server.
	TextDocumentSyncKind = {
		-- Documents should not be synced at all.
		None = 0;
		-- Documents are synced by always sending the full content
		-- of the document.
		Full = 1;
		-- Documents are synced by sending the full content on open.
		-- After that only incremental updates to the document are
		-- send.
		Incremental = 2;
	};

	WatchKind = {
		-- Interested in create events.
		Create = 1;
		-- Interested in change events
		Change = 2;
		-- Interested in delete events
		Delete = 4;
	};

	-- Defines whether the insert text in a completion item should be interpreted as
	-- plain text or a snippet.
	InsertTextFormat = {
		-- The primary text to be inserted is treated as a plain string.
		PlainText = 1;
		-- The primary text to be inserted is treated as a snippet.
		--
		-- A snippet can define tab stops and placeholders with `$1`, `$2`
		-- and `${3:foo};`. `$0` defines the final tab stop, it defaults to
		-- the end of the snippet. Placeholders with equal identifiers are linked,
		-- that is typing in one will update others too.
		Snippet = 2;
	};

	-- A set of predefined code action kinds
	CodeActionKind = {
		-- Empty kind.
		Empty = '';
		-- Base kind for quickfix actions
		QuickFix = 'quickfix';
		-- Base kind for refactoring actions
		Refactor = 'refactor';
		-- Base kind for refactoring extraction actions
		--
		-- Example extract actions:
		--
		-- - Extract method
		-- - Extract function
		-- - Extract variable
		-- - Extract interface from class
		-- - ...
		RefactorExtract = 'refactor.extract';
		-- Base kind for refactoring inline actions
		--
		-- Example inline actions:
		--
		-- - Inline function
		-- - Inline variable
		-- - Inline constant
		-- - ...
		RefactorInline = 'refactor.inline';
		-- Base kind for refactoring rewrite actions
		--
		-- Example rewrite actions:
		--
		-- - Convert JavaScript function to class
		-- - Add or remove parameter
		-- - Encapsulate field
		-- - Make method static
		-- - Move method to base class
		-- - ...
		RefactorRewrite = 'refactor.rewrite';
		-- Base kind for source actions
		--
		-- Source code actions apply to the entire file.
		Source = 'source';
		-- Base kind for an organize imports source action
		SourceOrganizeImports = 'source.organizeImports';
	};
}

for k, v in pairs(constants) do
	add_reverse_lookup(v)
	protocol[k] = v
end

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

protocol.EOL = function()
  if vim.api.nvim_buf_get_option(0, 'eol') then
    return "\n"
  else
    return ''
  end
end

protocol.DocumentUri = function(args)
  return args or vim.uri_from_bufnr()
end

protocol.languageId = function(args)
  return args or vim.api.nvim_buf_get_option(0, 'filetype')
end

local __document_version = {}
protocol.version = function(args)
  args = args or {}
  if type(args) == 'number' then return args end

  local uri = args.uri or protocol.DocumentUri()
  if not __document_version[uri] then __document_version[uri] = 0 end

  return args.version
    or __document_version[uri]
end

protocol.update_document_version = function(version, uri)
  uri = uri or protocol.DocumentUri()
  __document_version[uri] = version
end

local function get_buffer_text(bufnr)
  return table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')
end

protocol.text = function(args)
  return args or get_buffer_text(0)
end

protocol.TextDocumentIdentifier = function(args)
	args = args or {}
  return {
    uri = protocol.DocumentUri(args.uri),
  }
end

protocol.VersionedTextDocumentIdentifier = function(args)
	args = args or {}
  local identifier = protocol.TextDocumentIdentifier(args)
  identifier.version = protocol.version(args.version)

  return identifier
end

protocol.TextDocumentItem = function(args)
	args = args or {}
  return {
    uri = protocol.DocumentUri(args.uri),
    languageId = protocol.languageId(args.languageId),
    version = protocol.version(args.version),
    text = protocol.text(args.text),
  }
end

protocol.line = function(args)
  return args or (vim.fn.line('.') - 1)
end

protocol.character = function(args)
  return args or (vim.fn.col('.') - 1)
end

protocol.Position = function(args)
	args = args or {}
  return {
    line = protocol.line(args.line),
    character = protocol.character(args.character),
  }
end

protocol.TextDocumentPositionParams = function(args)
	args = args or {}
  return {
    textDocument = protocol.TextDocumentIdentifier(args.textDocument),
    position = protocol.Position(args.position),
  }
end

protocol.ReferenceContext = function(args)
	args = args or {}
  return {
    includeDeclaration = args.includeDeclaration or true,
  }
end

protocol.CompletionContext = function(args)
	args = args or {}
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

protocol.ClientCapabilities = function()
  return {
    textDocument = protocol.TextDocumentClientCapabilities,
  }
end

--- Parameter builder for request method
--
protocol.InitializeParams = function(client)
	local client_config = server_config.get_server(client.filetype, client.server_name)
	local capabilities = vim.tbl_extend('force', protocol.ClientCapabilities(), client_config.capabilities)

  local config = {
    processId = vim.fn.getpid(),
    rootUri = server_config.get_root_uri(client.filetype, client.server_name),
    capabilities = capabilities,
--    capabilities = protocol.ClientCapabilities(),
  }
  client:set_client_capabilities(config)
  return config
end

protocol.InitializedParams = function(_)
  return {}
end

protocol.CompletionParams = function(args)
	args = args or {}
  -- CompletionParams extends TextDocumentPositionParams with an optional context
  local params = protocol.TextDocumentPositionParams(args)
  params.context = protocol.CompletionContext(args.context)

  return params
end

protocol.HoverParams = function(args)
	args = args or {}
  return protocol.TextDocumentPositionParams(args)
end

protocol.SignatureHelpParams = function(args)
	args = args or {}
  local params =  protocol.TextDocumentPositionParams(args)
  params.position.character = params.position.character + 1

  return params
end

protocol.DefinitionParams = function(args)
	args = args or {}
  return protocol.TextDocumentPositionParams(args)
end

protocol.DocumentHighlightParams = function(args)
	args = args or {}
  return protocol.TextDocumentPositionParams(args)
end

protocol.ReferenceParams = function(args)
	args = args or {}
  local position = protocol.TextDocumentPositionParams(args)
  position.context = protocol.ReferenceContext(args.context)

  return position
end

protocol.RenameParams = function(args)
	args = args or {}
  return {
    textDocument = protocol.TextDocumentIdentifier(args.textDocument),
    position = protocol.Position(args.position),
    newName = args.newName or vim.fn.inputdialog('New Name: ');
  }
end

protocol.WorkspaceSymbolParams = function(args)
	args = args or {}
  return {
    query = args.query or vim.fn.expand('<cWORD>')
  }
end

--- Parameter builder for notification method
--
protocol.DidOpenTextDocumentParams = function(args)
	args = args or {}
  return {
    textDocument = protocol.TextDocumentItem(args.textDocument)
  }
end

protocol.WillSaveTextDocumentParams = function(args)
	args = args or {}
  return {
    textDocument = protocol.TextDocumentItem(args.textDocument),
    reason = args.reason or protocol.TextDocumentSaveReason.Manual,
  }
end

protocol.DidSaveTextDocumentParams = function(args)
	args = args or {}
  return {
    textDocument = protocol.TextDocumentItem(args.textDocument),
    text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n") .. protocol.EOL(),
  }
end

protocol.DidCloseTextDocumentParams = function(args)
	args = args or {}
  return {
    textDocument = protocol.TextDocumentItem(args.textDocument),
  }
end

return protocol
