-- Protocol for the Microsoft Language Server Protocol (mslsp)

local protocol = {}

--[=[
---@private
--- Useful for interfacing with:
--- https://github.com/microsoft/language-server-protocol/raw/gh-pages/_specifications/specification-3-14.md
function transform_schema_comments()
  nvim.command [[silent! '<,'>g/\/\*\*\|\*\/\|^$/d]]
  nvim.command [[silent! '<,'>s/^\(\s*\) \* \=\(.*\)/\1--\2/]]
end
---@private
function transform_schema_to_table()
  transform_schema_comments()
  nvim.command [[silent! '<,'>s/: \S\+//]]
  nvim.command [[silent! '<,'>s/export const //]]
  nvim.command [[silent! '<,'>s/export namespace \(\S*\)\s*{/protocol.\1 = {/]]
  nvim.command [[silent! '<,'>s/namespace \(\S*\)\s*{/protocol.\1 = {/]]
end
--]=]

local constants = {
  --- @enum lsp.DiagnosticSeverity
  DiagnosticSeverity = {
    -- Reports an error.
    Error = 1,
    -- Reports a warning.
    Warning = 2,
    -- Reports an information.
    Information = 3,
    -- Reports a hint.
    Hint = 4,
  },

  --- @enum lsp.DiagnosticTag
  DiagnosticTag = {
    -- Unused or unnecessary code
    Unnecessary = 1,
    -- Deprecated or obsolete code
    Deprecated = 2,
  },

  ---@enum lsp.MessageType
  MessageType = {
    -- An error message.
    Error = 1,
    -- A warning message.
    Warning = 2,
    -- An information message.
    Info = 3,
    -- A log message.
    Log = 4,
  },

  -- The file event type.
  ---@enum lsp.FileChangeType
  FileChangeType = {
    -- The file got created.
    Created = 1,
    -- The file got changed.
    Changed = 2,
    -- The file got deleted.
    Deleted = 3,
  },

  -- The kind of a completion entry.
  CompletionItemKind = {
    Text = 1,
    Method = 2,
    Function = 3,
    Constructor = 4,
    Field = 5,
    Variable = 6,
    Class = 7,
    Interface = 8,
    Module = 9,
    Property = 10,
    Unit = 11,
    Value = 12,
    Enum = 13,
    Keyword = 14,
    Snippet = 15,
    Color = 16,
    File = 17,
    Reference = 18,
    Folder = 19,
    EnumMember = 20,
    Constant = 21,
    Struct = 22,
    Event = 23,
    Operator = 24,
    TypeParameter = 25,
  },

  -- How a completion was triggered
  CompletionTriggerKind = {
    -- Completion was triggered by typing an identifier (24x7 code
    -- complete), manual invocation (e.g Ctrl+Space) or via API.
    Invoked = 1,
    -- Completion was triggered by a trigger character specified by
    -- the `triggerCharacters` properties of the `CompletionRegistrationOptions`.
    TriggerCharacter = 2,
    -- Completion was re-triggered as the current completion list is incomplete.
    TriggerForIncompleteCompletions = 3,
  },

  -- A document highlight kind.
  DocumentHighlightKind = {
    -- A textual occurrence.
    Text = 1,
    -- Read-access of a symbol, like reading a variable.
    Read = 2,
    -- Write-access of a symbol, like writing to a variable.
    Write = 3,
  },

  -- A symbol kind.
  SymbolKind = {
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
    Object = 19,
    Key = 20,
    Null = 21,
    EnumMember = 22,
    Struct = 23,
    Event = 24,
    Operator = 25,
    TypeParameter = 26,
  },

  -- Represents reasons why a text document is saved.
  ---@enum lsp.TextDocumentSaveReason
  TextDocumentSaveReason = {
    -- Manually triggered, e.g. by the user pressing save, by starting debugging,
    -- or by an API call.
    Manual = 1,
    -- Automatic after a delay.
    AfterDelay = 2,
    -- When the editor lost focus.
    FocusOut = 3,
  },

  ErrorCodes = {
    -- Defined by JSON RPC
    ParseError = -32700,
    InvalidRequest = -32600,
    MethodNotFound = -32601,
    InvalidParams = -32602,
    InternalError = -32603,
    serverErrorStart = -32099,
    serverErrorEnd = -32000,
    ServerNotInitialized = -32002,
    UnknownErrorCode = -32001,
    -- Defined by the protocol.
    RequestCancelled = -32800,
    ContentModified = -32801,
  },

  -- Describes the content type that a client supports in various
  -- result literals like `Hover`, `ParameterInfo` or `CompletionItem`.
  --
  -- Please note that `MarkupKinds` must not start with a `$`. This kinds
  -- are reserved for internal usage.
  MarkupKind = {
    -- Plain text is supported as a content format
    PlainText = 'plaintext',
    -- Markdown is supported as a content format
    Markdown = 'markdown',
  },

  ResourceOperationKind = {
    -- Supports creating new files and folders.
    Create = 'create',
    -- Supports renaming existing files and folders.
    Rename = 'rename',
    -- Supports deleting existing files and folders.
    Delete = 'delete',
  },

  FailureHandlingKind = {
    -- Applying the workspace change is simply aborted if one of the changes provided
    -- fails. All operations executed before the failing operation stay executed.
    Abort = 'abort',
    -- All operations are executed transactionally. That means they either all
    -- succeed or no changes at all are applied to the workspace.
    Transactional = 'transactional',
    -- If the workspace edit contains only textual file changes they are executed transactionally.
    -- If resource changes (create, rename or delete file) are part of the change the failure
    -- handling strategy is abort.
    TextOnlyTransactional = 'textOnlyTransactional',
    -- The client tries to undo the operations already executed. But there is no
    -- guarantee that this succeeds.
    Undo = 'undo',
  },

  -- Known error codes for an `InitializeError`;
  InitializeError = {
    -- If the protocol version provided by the client can't be handled by the server.
    -- @deprecated This initialize error got replaced by client capabilities. There is
    -- no version handshake in version 3.0x
    unknownProtocolVersion = 1,
  },

  -- Defines how the host (editor) should sync document changes to the language server.
  TextDocumentSyncKind = {
    -- Documents should not be synced at all.
    None = 0,
    -- Documents are synced by always sending the full content
    -- of the document.
    Full = 1,
    -- Documents are synced by sending the full content on open.
    -- After that only incremental updates to the document are
    -- send.
    Incremental = 2,
  },

  WatchKind = {
    -- Interested in create events.
    Create = 1,
    -- Interested in change events
    Change = 2,
    -- Interested in delete events
    Delete = 4,
  },

  -- Defines whether the insert text in a completion item should be interpreted as
  -- plain text or a snippet.
  InsertTextFormat = {
    -- The primary text to be inserted is treated as a plain string.
    PlainText = 1,
    -- The primary text to be inserted is treated as a snippet.
    --
    -- A snippet can define tab stops and placeholders with `$1`, `$2`
    -- and `${3:foo};`. `$0` defines the final tab stop, it defaults to
    -- the end of the snippet. Placeholders with equal identifiers are linked,
    -- that is typing in one will update others too.
    Snippet = 2,
  },

  -- A set of predefined code action kinds
  CodeActionKind = {
    -- Empty kind.
    Empty = '',
    -- Base kind for quickfix actions
    QuickFix = 'quickfix',
    -- Base kind for refactoring actions
    Refactor = 'refactor',
    -- Base kind for refactoring extraction actions
    --
    -- Example extract actions:
    --
    -- - Extract method
    -- - Extract function
    -- - Extract variable
    -- - Extract interface from class
    -- - ...
    RefactorExtract = 'refactor.extract',
    -- Base kind for refactoring inline actions
    --
    -- Example inline actions:
    --
    -- - Inline function
    -- - Inline variable
    -- - Inline constant
    -- - ...
    RefactorInline = 'refactor.inline',
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
    RefactorRewrite = 'refactor.rewrite',
    -- Base kind for source actions
    --
    -- Source code actions apply to the entire file.
    Source = 'source',
    -- Base kind for an organize imports source action
    SourceOrganizeImports = 'source.organizeImports',
  },
  -- The reason why code actions were requested.
  ---@enum lsp.CodeActionTriggerKind
  CodeActionTriggerKind = {
    -- Code actions were explicitly requested by the user or by an extension.
    Invoked = 1,
    -- Code actions were requested automatically.
    --
    -- This typically happens when current selection in a file changes, but can
    -- also be triggered when file content changes.
    Automatic = 2,
  },
}

for k, v in pairs(constants) do
  local tbl = vim.deepcopy(v)
  vim.tbl_add_reverse_lookup(tbl)
  protocol[k] = tbl
end

--[=[
--Text document specific client capabilities.
export interface TextDocumentClientCapabilities {
  synchronization?: {
    --Whether text document synchronization supports dynamic registration.
    dynamicRegistration?: boolean;
    --The client supports sending will save notifications.
    willSave?: boolean;
    --The client supports sending a will save request and
    --waits for a response providing text edits which will
    --be applied to the document before it is saved.
    willSaveWaitUntil?: boolean;
    --The client supports did save notifications.
    didSave?: boolean;
  }
  --Capabilities specific to the `textDocument/completion`
  completion?: {
    --Whether completion supports dynamic registration.
    dynamicRegistration?: boolean;
    --The client supports the following `CompletionItem` specific
    --capabilities.
    completionItem?: {
      --The client supports snippets as insert text.
      --
      --A snippet can define tab stops and placeholders with `$1`, `$2`
      --and `${3:foo}`. `$0` defines the final tab stop, it defaults to
      --the end of the snippet. Placeholders with equal identifiers are linked,
      --that is typing in one will update others too.
      snippetSupport?: boolean;
      --The client supports commit characters on a completion item.
      commitCharactersSupport?: boolean
      --The client supports the following content formats for the documentation
      --property. The order describes the preferred format of the client.
      documentationFormat?: MarkupKind[];
      --The client supports the deprecated property on a completion item.
      deprecatedSupport?: boolean;
      --The client supports the preselect property on a completion item.
      preselectSupport?: boolean;
    }
    completionItemKind?: {
      --The completion item kind values the client supports. When this
      --property exists the client also guarantees that it will
      --handle values outside its set gracefully and falls back
      --to a default value when unknown.
      --
      --If this property is not present the client only supports
      --the completion items kinds from `Text` to `Reference` as defined in
      --the initial version of the protocol.
      valueSet?: CompletionItemKind[];
    },
    --The client supports to send additional context information for a
    --`textDocument/completion` request.
    contextSupport?: boolean;
  };
  --Capabilities specific to the `textDocument/hover`
  hover?: {
    --Whether hover supports dynamic registration.
    dynamicRegistration?: boolean;
    --The client supports the follow content formats for the content
    --property. The order describes the preferred format of the client.
    contentFormat?: MarkupKind[];
  };
  --Capabilities specific to the `textDocument/signatureHelp`
  signatureHelp?: {
    --Whether signature help supports dynamic registration.
    dynamicRegistration?: boolean;
    --The client supports the following `SignatureInformation`
    --specific properties.
    signatureInformation?: {
      --The client supports the follow content formats for the documentation
      --property. The order describes the preferred format of the client.
      documentationFormat?: MarkupKind[];
      --Client capabilities specific to parameter information.
      parameterInformation?: {
        --The client supports processing label offsets instead of a
        --simple label string.
        --
        --Since 3.14.0
        labelOffsetSupport?: boolean;
      }
    };
  };
  --Capabilities specific to the `textDocument/references`
  references?: {
    --Whether references supports dynamic registration.
    dynamicRegistration?: boolean;
  };
  --Capabilities specific to the `textDocument/documentHighlight`
  documentHighlight?: {
    --Whether document highlight supports dynamic registration.
    dynamicRegistration?: boolean;
  };
  --Capabilities specific to the `textDocument/documentSymbol`
  documentSymbol?: {
    --Whether document symbol supports dynamic registration.
    dynamicRegistration?: boolean;
    --Specific capabilities for the `SymbolKind`.
    symbolKind?: {
      --The symbol kind values the client supports. When this
      --property exists the client also guarantees that it will
      --handle values outside its set gracefully and falls back
      --to a default value when unknown.
      --
      --If this property is not present the client only supports
      --the symbol kinds from `File` to `Array` as defined in
      --the initial version of the protocol.
      valueSet?: SymbolKind[];
    }
    --The client supports hierarchical document symbols.
    hierarchicalDocumentSymbolSupport?: boolean;
  };
  --Capabilities specific to the `textDocument/formatting`
  formatting?: {
    --Whether formatting supports dynamic registration.
    dynamicRegistration?: boolean;
  };
  --Capabilities specific to the `textDocument/rangeFormatting`
  rangeFormatting?: {
    --Whether range formatting supports dynamic registration.
    dynamicRegistration?: boolean;
  };
  --Capabilities specific to the `textDocument/onTypeFormatting`
  onTypeFormatting?: {
    --Whether on type formatting supports dynamic registration.
    dynamicRegistration?: boolean;
  };
  --Capabilities specific to the `textDocument/declaration`
  declaration?: {
    --Whether declaration supports dynamic registration. If this is set to `true`
    --the client supports the new `(TextDocumentRegistrationOptions & StaticRegistrationOptions)`
    --return value for the corresponding server capability as well.
    dynamicRegistration?: boolean;
    --The client supports additional metadata in the form of declaration links.
    --
    --Since 3.14.0
    linkSupport?: boolean;
  };
  --Capabilities specific to the `textDocument/definition`.
  --
  --Since 3.14.0
  definition?: {
    --Whether definition supports dynamic registration.
    dynamicRegistration?: boolean;
    --The client supports additional metadata in the form of definition links.
    linkSupport?: boolean;
  };
  --Capabilities specific to the `textDocument/typeDefinition`
  --
  --Since 3.6.0
  typeDefinition?: {
    --Whether typeDefinition supports dynamic registration. If this is set to `true`
    --the client supports the new `(TextDocumentRegistrationOptions & StaticRegistrationOptions)`
    --return value for the corresponding server capability as well.
    dynamicRegistration?: boolean;
    --The client supports additional metadata in the form of definition links.
    --
    --Since 3.14.0
    linkSupport?: boolean;
  };
  --Capabilities specific to the `textDocument/implementation`.
  --
  --Since 3.6.0
  implementation?: {
    --Whether implementation supports dynamic registration. If this is set to `true`
    --the client supports the new `(TextDocumentRegistrationOptions & StaticRegistrationOptions)`
    --return value for the corresponding server capability as well.
    dynamicRegistration?: boolean;
    --The client supports additional metadata in the form of definition links.
    --
    --Since 3.14.0
    linkSupport?: boolean;
  };
  --Capabilities specific to the `textDocument/codeAction`
  codeAction?: {
    --Whether code action supports dynamic registration.
    dynamicRegistration?: boolean;
    --The client support code action literals as a valid
    --response of the `textDocument/codeAction` request.
    --
    --Since 3.8.0
    codeActionLiteralSupport?: {
      --The code action kind is support with the following value
      --set.
      codeActionKind: {
        --The code action kind values the client supports. When this
        --property exists the client also guarantees that it will
        --handle values outside its set gracefully and falls back
        --to a default value when unknown.
        valueSet: CodeActionKind[];
      };
    };
  };
  --Capabilities specific to the `textDocument/codeLens`
  codeLens?: {
    --Whether code lens supports dynamic registration.
    dynamicRegistration?: boolean;
  };
  --Capabilities specific to the `textDocument/documentLink`
  documentLink?: {
    --Whether document link supports dynamic registration.
    dynamicRegistration?: boolean;
  };
  --Capabilities specific to the `textDocument/documentColor` and the
  --`textDocument/colorPresentation` request.
  --
  --Since 3.6.0
  colorProvider?: {
    --Whether colorProvider supports dynamic registration. If this is set to `true`
    --the client supports the new `(ColorProviderOptions & TextDocumentRegistrationOptions & StaticRegistrationOptions)`
    --return value for the corresponding server capability as well.
    dynamicRegistration?: boolean;
  }
  --Capabilities specific to the `textDocument/rename`
  rename?: {
    --Whether rename supports dynamic registration.
    dynamicRegistration?: boolean;
    --The client supports testing for validity of rename operations
    --before execution.
    prepareSupport?: boolean;
  };
  --Capabilities specific to `textDocument/publishDiagnostics`.
  publishDiagnostics?: {
    --Whether the clients accepts diagnostics with related information.
    relatedInformation?: boolean;
    --Client supports the tag property to provide meta data about a diagnostic.
	  --Clients supporting tags have to handle unknown tags gracefully.
    --Since 3.15.0
    tagSupport?: {
      --The tags supported by this client
      valueSet: DiagnosticTag[];
    };
  };
  --Capabilities specific to `textDocument/foldingRange` requests.
  --
  --Since 3.10.0
  foldingRange?: {
    --Whether implementation supports dynamic registration for folding range providers. If this is set to `true`
    --the client supports the new `(FoldingRangeProviderOptions & TextDocumentRegistrationOptions & StaticRegistrationOptions)`
    --return value for the corresponding server capability as well.
    dynamicRegistration?: boolean;
    --The maximum number of folding ranges that the client prefers to receive per document. The value serves as a
    --hint, servers are free to follow the limit.
    rangeLimit?: number;
    --If set, the client signals that it only supports folding complete lines. If set, client will
    --ignore specified `startCharacter` and `endCharacter` properties in a FoldingRange.
    lineFoldingOnly?: boolean;
  };
}
--]=]

--[=[
--Workspace specific client capabilities.
export interface WorkspaceClientCapabilities {
  --The client supports applying batch edits to the workspace by supporting
  --the request 'workspace/applyEdit'
  applyEdit?: boolean;
  --Capabilities specific to `WorkspaceEdit`s
  workspaceEdit?: {
    --The client supports versioned document changes in `WorkspaceEdit`s
    documentChanges?: boolean;
    --The resource operations the client supports. Clients should at least
    --support 'create', 'rename' and 'delete' files and folders.
    resourceOperations?: ResourceOperationKind[];
    --The failure handling strategy of a client if applying the workspace edit
    --fails.
    failureHandling?: FailureHandlingKind;
  };
  --Capabilities specific to the `workspace/didChangeConfiguration` notification.
  didChangeConfiguration?: {
    --Did change configuration notification supports dynamic registration.
    dynamicRegistration?: boolean;
  };
  --Capabilities specific to the `workspace/didChangeWatchedFiles` notification.
  didChangeWatchedFiles?: {
    --Did change watched files notification supports dynamic registration. Please note
    --that the current protocol doesn't support static configuration for file changes
    --from the server side.
    dynamicRegistration?: boolean;
  };
  --Capabilities specific to the `workspace/symbol` request.
  symbol?: {
    --Symbol request supports dynamic registration.
    dynamicRegistration?: boolean;
    --Specific capabilities for the `SymbolKind` in the `workspace/symbol` request.
    symbolKind?: {
      --The symbol kind values the client supports. When this
      --property exists the client also guarantees that it will
      --handle values outside its set gracefully and falls back
      --to a default value when unknown.
      --
      --If this property is not present the client only supports
      --the symbol kinds from `File` to `Array` as defined in
      --the initial version of the protocol.
      valueSet?: SymbolKind[];
    }
  };
  --Capabilities specific to the `workspace/executeCommand` request.
  executeCommand?: {
    --Execute command supports dynamic registration.
    dynamicRegistration?: boolean;
  };
  --The client has support for workspace folders.
  --
  --Since 3.6.0
  workspaceFolders?: boolean;
  --The client supports `workspace/configuration` requests.
  --
  --Since 3.6.0
  configuration?: boolean;
}
--]=]

--- Gets a new ClientCapabilities object describing the LSP client
--- capabilities.
--- @return lsp.ClientCapabilities
function protocol.make_client_capabilities()
  return {
    general = {
      positionEncodings = {
        'utf-16',
      },
    },
    textDocument = {
      diagnostic = {
        dynamicRegistration = false,
      },
      inlayHint = {
        dynamicRegistration = true,
        resolveSupport = {
          properties = {},
        },
      },
      semanticTokens = {
        dynamicRegistration = false,
        tokenTypes = {
          'namespace',
          'type',
          'class',
          'enum',
          'interface',
          'struct',
          'typeParameter',
          'parameter',
          'variable',
          'property',
          'enumMember',
          'event',
          'function',
          'method',
          'macro',
          'keyword',
          'modifier',
          'comment',
          'string',
          'number',
          'regexp',
          'operator',
          'decorator',
        },
        tokenModifiers = {
          'declaration',
          'definition',
          'readonly',
          'static',
          'deprecated',
          'abstract',
          'async',
          'modification',
          'documentation',
          'defaultLibrary',
        },
        formats = { 'relative' },
        requests = {
          -- TODO(jdrouhard): Add support for this
          range = false,
          full = { delta = true },
        },

        overlappingTokenSupport = true,
        -- TODO(jdrouhard): Add support for this
        multilineTokenSupport = false,
        serverCancelSupport = false,
        augmentsSyntaxTokens = true,
      },
      synchronization = {
        dynamicRegistration = false,

        willSave = true,
        willSaveWaitUntil = true,

        -- Send textDocument/didSave after saving (BufWritePost)
        didSave = true,
      },
      codeAction = {
        dynamicRegistration = true,

        codeActionLiteralSupport = {
          codeActionKind = {
            valueSet = (function()
              local res = vim.tbl_values(constants.CodeActionKind)
              table.sort(res)
              return res
            end)(),
          },
        },
        isPreferredSupport = true,
        dataSupport = true,
        resolveSupport = {
          properties = { 'edit' },
        },
      },
      formatting = {
        dynamicRegistration = true,
      },
      rangeFormatting = {
        dynamicRegistration = true,
      },
      completion = {
        dynamicRegistration = false,
        completionItem = {
          -- Until we can actually expand snippet, move cursor and allow for true snippet experience,
          -- this should be disabled out of the box.
          -- However, users can turn this back on if they have a snippet plugin.
          snippetSupport = false,

          commitCharactersSupport = false,
          preselectSupport = false,
          deprecatedSupport = false,
          documentationFormat = { protocol.MarkupKind.Markdown, protocol.MarkupKind.PlainText },
        },
        completionItemKind = {
          valueSet = (function()
            local res = {}
            for k in ipairs(protocol.CompletionItemKind) do
              if type(k) == 'number' then
                table.insert(res, k)
              end
            end
            return res
          end)(),
        },

        -- TODO(tjdevries): Implement this
        contextSupport = false,
      },
      declaration = {
        linkSupport = true,
      },
      definition = {
        linkSupport = true,
        dynamicRegistration = true,
      },
      implementation = {
        linkSupport = true,
      },
      typeDefinition = {
        linkSupport = true,
      },
      hover = {
        dynamicRegistration = true,
        contentFormat = { protocol.MarkupKind.Markdown, protocol.MarkupKind.PlainText },
      },
      signatureHelp = {
        dynamicRegistration = false,
        signatureInformation = {
          activeParameterSupport = true,
          documentationFormat = { protocol.MarkupKind.Markdown, protocol.MarkupKind.PlainText },
          parameterInformation = {
            labelOffsetSupport = true,
          },
        },
      },
      references = {
        dynamicRegistration = false,
      },
      documentHighlight = {
        dynamicRegistration = false,
      },
      documentSymbol = {
        dynamicRegistration = false,
        symbolKind = {
          valueSet = (function()
            local res = {}
            for k in ipairs(protocol.SymbolKind) do
              if type(k) == 'number' then
                table.insert(res, k)
              end
            end
            return res
          end)(),
        },
        hierarchicalDocumentSymbolSupport = true,
      },
      rename = {
        dynamicRegistration = true,
        prepareSupport = true,
      },
      publishDiagnostics = {
        relatedInformation = true,
        tagSupport = {
          valueSet = (function()
            local res = {}
            for k in ipairs(protocol.DiagnosticTag) do
              if type(k) == 'number' then
                table.insert(res, k)
              end
            end
            return res
          end)(),
        },
        dataSupport = true,
      },
      callHierarchy = {
        dynamicRegistration = false,
      },
    },
    workspace = {
      symbol = {
        dynamicRegistration = false,
        symbolKind = {
          valueSet = (function()
            local res = {}
            for k in ipairs(protocol.SymbolKind) do
              if type(k) == 'number' then
                table.insert(res, k)
              end
            end
            return res
          end)(),
        },
      },
      configuration = true,
      workspaceFolders = true,
      applyEdit = true,
      workspaceEdit = {
        resourceOperations = { 'rename', 'create', 'delete' },
      },
      semanticTokens = {
        refreshSupport = true,
      },
      didChangeWatchedFiles = {
        dynamicRegistration = true,
        relativePatternSupport = true,
      },
      inlayHint = {
        refreshSupport = true,
      },
    },
    experimental = nil,
    window = {
      workDoneProgress = true,
      showMessage = {
        messageActionItem = {
          additionalPropertiesSupport = false,
        },
      },
      showDocument = {
        support = true,
      },
    },
  }
end

--- Creates a normalized object describing LSP server capabilities.
---@param server_capabilities table Table of capabilities supported by the server
---@return table|nil Normalized table of capabilities
function protocol.resolve_capabilities(server_capabilities)
  local TextDocumentSyncKind = protocol.TextDocumentSyncKind
  local textDocumentSync = server_capabilities.textDocumentSync
  if textDocumentSync == nil then
    -- Defaults if omitted.
    server_capabilities.textDocumentSync = {
      openClose = false,
      change = TextDocumentSyncKind.None,
      willSave = false,
      willSaveWaitUntil = false,
      save = {
        includeText = false,
      },
    }
  elseif type(textDocumentSync) == 'number' then
    -- Backwards compatibility
    if not TextDocumentSyncKind[textDocumentSync] then
      vim.notify('Invalid server TextDocumentSyncKind for textDocumentSync', vim.log.levels.ERROR)
      return nil
    end
    server_capabilities.textDocumentSync = {
      openClose = true,
      change = textDocumentSync,
      willSave = false,
      willSaveWaitUntil = false,
      save = {
        includeText = false,
      },
    }
  elseif type(textDocumentSync) ~= 'table' then
    vim.notify(
      string.format('Invalid type for textDocumentSync: %q', type(textDocumentSync)),
      vim.log.levels.ERROR
    )
    return nil
  end
  return server_capabilities
end

-- Generated by gen_lsp.lua, keep at end of file.
--- LSP method names.
---
---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#metaModel
protocol.Methods = {
  --- A request to resolve the incoming calls for a given `CallHierarchyItem`.
  --- @since 3.16.0
  callHierarchy_incomingCalls = 'callHierarchy/incomingCalls',
  --- A request to resolve the outgoing calls for a given `CallHierarchyItem`.
  --- @since 3.16.0
  callHierarchy_outgoingCalls = 'callHierarchy/outgoingCalls',
  --- The `client/registerCapability` request is sent from the server to the client to register a new capability
  --- handler on the client side.
  client_registerCapability = 'client/registerCapability',
  --- The `client/unregisterCapability` request is sent from the server to the client to unregister a previously registered capability
  --- handler on the client side.
  client_unregisterCapability = 'client/unregisterCapability',
  --- Request to resolve additional information for a given code action.The request's
  --- parameter is of type {@link CodeAction} the response
  --- is of type {@link CodeAction} or a Thenable that resolves to such.
  codeAction_resolve = 'codeAction/resolve',
  --- A request to resolve a command for a given code lens.
  codeLens_resolve = 'codeLens/resolve',
  --- Request to resolve additional information for a given completion item.The request's
  --- parameter is of type {@link CompletionItem} the response
  --- is of type {@link CompletionItem} or a Thenable that resolves to such.
  completionItem_resolve = 'completionItem/resolve',
  --- Request to resolve additional information for a given document link. The request's
  --- parameter is of type {@link DocumentLink} the response
  --- is of type {@link DocumentLink} or a Thenable that resolves to such.
  documentLink_resolve = 'documentLink/resolve',
  dollar_cancelRequest = '$/cancelRequest',
  dollar_logTrace = '$/logTrace',
  dollar_progress = '$/progress',
  dollar_setTrace = '$/setTrace',
  --- The exit event is sent from the client to the server to
  --- ask the server to exit its process.
  exit = 'exit',
  --- The initialize request is sent from the client to the server.
  --- It is sent once as the request after starting up the server.
  --- The requests parameter is of type {@link InitializeParams}
  --- the response if of type {@link InitializeResult} of a Thenable that
  --- resolves to such.
  initialize = 'initialize',
  --- The initialized notification is sent from the client to the
  --- server after the client is fully initialized and the server
  --- is allowed to send requests from the server to the client.
  initialized = 'initialized',
  --- A request to resolve additional properties for an inlay hint.
  --- The request's parameter is of type {@link InlayHint}, the response is
  --- of type {@link InlayHint} or a Thenable that resolves to such.
  --- @since 3.17.0
  inlayHint_resolve = 'inlayHint/resolve',
  notebookDocument_didChange = 'notebookDocument/didChange',
  --- A notification sent when a notebook closes.
  --- @since 3.17.0
  notebookDocument_didClose = 'notebookDocument/didClose',
  --- A notification sent when a notebook opens.
  --- @since 3.17.0
  notebookDocument_didOpen = 'notebookDocument/didOpen',
  --- A notification sent when a notebook document is saved.
  --- @since 3.17.0
  notebookDocument_didSave = 'notebookDocument/didSave',
  --- A shutdown request is sent from the client to the server.
  --- It is sent once when the client decides to shutdown the
  --- server. The only notification that is sent after a shutdown request
  --- is the exit event.
  shutdown = 'shutdown',
  --- The telemetry event notification is sent from the server to the client to ask
  --- the client to log telemetry data.
  telemetry_event = 'telemetry/event',
  --- A request to provide commands for the given text document and range.
  textDocument_codeAction = 'textDocument/codeAction',
  --- A request to provide code lens for the given text document.
  textDocument_codeLens = 'textDocument/codeLens',
  --- A request to list all presentation for a color. The request's
  --- parameter is of type {@link ColorPresentationParams} the
  --- response is of type {@link ColorInformation ColorInformation[]} or a Thenable
  --- that resolves to such.
  textDocument_colorPresentation = 'textDocument/colorPresentation',
  --- Request to request completion at a given text document position. The request's
  --- parameter is of type {@link TextDocumentPosition} the response
  --- is of type {@link CompletionItem CompletionItem[]} or {@link CompletionList}
  --- or a Thenable that resolves to such.
  --- The request can delay the computation of the {@link CompletionItem.detail `detail`}
  --- and {@link CompletionItem.documentation `documentation`} properties to the `completionItem/resolve`
  --- request. However, properties that are needed for the initial sorting and filtering, like `sortText`,
  --- `filterText`, `insertText`, and `textEdit`, must not be changed during resolve.
  textDocument_completion = 'textDocument/completion',
  --- A request to resolve the type definition locations of a symbol at a given text
  --- document position. The request's parameter is of type [TextDocumentPositionParams]
  --- (#TextDocumentPositionParams) the response is of type {@link Declaration}
  --- or a typed array of {@link DeclarationLink} or a Thenable that resolves
  --- to such.
  textDocument_declaration = 'textDocument/declaration',
  --- A request to resolve the definition location of a symbol at a given text
  --- document position. The request's parameter is of type [TextDocumentPosition]
  --- (#TextDocumentPosition) the response is of either type {@link Definition}
  --- or a typed array of {@link DefinitionLink} or a Thenable that resolves
  --- to such.
  textDocument_definition = 'textDocument/definition',
  --- The document diagnostic request definition.
  --- @since 3.17.0
  textDocument_diagnostic = 'textDocument/diagnostic',
  --- The document change notification is sent from the client to the server to signal
  --- changes to a text document.
  textDocument_didChange = 'textDocument/didChange',
  --- The document close notification is sent from the client to the server when
  --- the document got closed in the client. The document's truth now exists where
  --- the document's uri points to (e.g. if the document's uri is a file uri the
  --- truth now exists on disk). As with the open notification the close notification
  --- is about managing the document's content. Receiving a close notification
  --- doesn't mean that the document was open in an editor before. A close
  --- notification requires a previous open notification to be sent.
  textDocument_didClose = 'textDocument/didClose',
  --- The document open notification is sent from the client to the server to signal
  --- newly opened text documents. The document's truth is now managed by the client
  --- and the server must not try to read the document's truth using the document's
  --- uri. Open in this sense means it is managed by the client. It doesn't necessarily
  --- mean that its content is presented in an editor. An open notification must not
  --- be sent more than once without a corresponding close notification send before.
  --- This means open and close notification must be balanced and the max open count
  --- is one.
  textDocument_didOpen = 'textDocument/didOpen',
  --- The document save notification is sent from the client to the server when
  --- the document got saved in the client.
  textDocument_didSave = 'textDocument/didSave',
  --- A request to list all color symbols found in a given text document. The request's
  --- parameter is of type {@link DocumentColorParams} the
  --- response is of type {@link ColorInformation ColorInformation[]} or a Thenable
  --- that resolves to such.
  textDocument_documentColor = 'textDocument/documentColor',
  --- Request to resolve a {@link DocumentHighlight} for a given
  --- text document position. The request's parameter is of type [TextDocumentPosition]
  --- (#TextDocumentPosition) the request response is of type [DocumentHighlight[]]
  --- (#DocumentHighlight) or a Thenable that resolves to such.
  textDocument_documentHighlight = 'textDocument/documentHighlight',
  --- A request to provide document links
  textDocument_documentLink = 'textDocument/documentLink',
  --- A request to list all symbols found in a given text document. The request's
  --- parameter is of type {@link TextDocumentIdentifier} the
  --- response is of type {@link SymbolInformation SymbolInformation[]} or a Thenable
  --- that resolves to such.
  textDocument_documentSymbol = 'textDocument/documentSymbol',
  --- A request to provide folding ranges in a document. The request's
  --- parameter is of type {@link FoldingRangeParams}, the
  --- response is of type {@link FoldingRangeList} or a Thenable
  --- that resolves to such.
  textDocument_foldingRange = 'textDocument/foldingRange',
  --- A request to to format a whole document.
  textDocument_formatting = 'textDocument/formatting',
  --- Request to request hover information at a given text document position. The request's
  --- parameter is of type {@link TextDocumentPosition} the response is of
  --- type {@link Hover} or a Thenable that resolves to such.
  textDocument_hover = 'textDocument/hover',
  --- A request to resolve the implementation locations of a symbol at a given text
  --- document position. The request's parameter is of type [TextDocumentPositionParams]
  --- (#TextDocumentPositionParams) the response is of type {@link Definition} or a
  --- Thenable that resolves to such.
  textDocument_implementation = 'textDocument/implementation',
  --- A request to provide inlay hints in a document. The request's parameter is of
  --- type {@link InlayHintsParams}, the response is of type
  --- {@link InlayHint InlayHint[]} or a Thenable that resolves to such.
  --- @since 3.17.0
  textDocument_inlayHint = 'textDocument/inlayHint',
  --- A request to provide inline completions in a document. The request's parameter is of
  --- type {@link InlineCompletionParams}, the response is of type
  --- {@link InlineCompletion InlineCompletion[]} or a Thenable that resolves to such.
  --- @since 3.18.0
  textDocument_inlineCompletion = 'textDocument/inlineCompletion',
  --- A request to provide inline values in a document. The request's parameter is of
  --- type {@link InlineValueParams}, the response is of type
  --- {@link InlineValue InlineValue[]} or a Thenable that resolves to such.
  --- @since 3.17.0
  textDocument_inlineValue = 'textDocument/inlineValue',
  --- A request to provide ranges that can be edited together.
  --- @since 3.16.0
  textDocument_linkedEditingRange = 'textDocument/linkedEditingRange',
  --- A request to get the moniker of a symbol at a given text document position.
  --- The request parameter is of type {@link TextDocumentPositionParams}.
  --- The response is of type {@link Moniker Moniker[]} or `null`.
  textDocument_moniker = 'textDocument/moniker',
  --- A request to format a document on type.
  textDocument_onTypeFormatting = 'textDocument/onTypeFormatting',
  --- A request to result a `CallHierarchyItem` in a document at a given position.
  --- Can be used as an input to an incoming or outgoing call hierarchy.
  --- @since 3.16.0
  textDocument_prepareCallHierarchy = 'textDocument/prepareCallHierarchy',
  --- A request to test and perform the setup necessary for a rename.
  --- @since 3.16 - support for default behavior
  textDocument_prepareRename = 'textDocument/prepareRename',
  --- A request to result a `TypeHierarchyItem` in a document at a given position.
  --- Can be used as an input to a subtypes or supertypes type hierarchy.
  --- @since 3.17.0
  textDocument_prepareTypeHierarchy = 'textDocument/prepareTypeHierarchy',
  --- Diagnostics notification are sent from the server to the client to signal
  --- results of validation runs.
  textDocument_publishDiagnostics = 'textDocument/publishDiagnostics',
  --- A request to format a range in a document.
  textDocument_rangeFormatting = 'textDocument/rangeFormatting',
  --- A request to format ranges in a document.
  --- @since 3.18.0
  --- @proposed
  textDocument_rangesFormatting = 'textDocument/rangesFormatting',
  --- A request to resolve project-wide references for the symbol denoted
  --- by the given text document position. The request's parameter is of
  --- type {@link ReferenceParams} the response is of type
  --- {@link Location Location[]} or a Thenable that resolves to such.
  textDocument_references = 'textDocument/references',
  --- A request to rename a symbol.
  textDocument_rename = 'textDocument/rename',
  --- A request to provide selection ranges in a document. The request's
  --- parameter is of type {@link SelectionRangeParams}, the
  --- response is of type {@link SelectionRange SelectionRange[]} or a Thenable
  --- that resolves to such.
  textDocument_selectionRange = 'textDocument/selectionRange',
  --- @since 3.16.0
  textDocument_semanticTokens_full = 'textDocument/semanticTokens/full',
  --- @since 3.16.0
  textDocument_semanticTokens_full_delta = 'textDocument/semanticTokens/full/delta',
  --- @since 3.16.0
  textDocument_semanticTokens_range = 'textDocument/semanticTokens/range',
  textDocument_signatureHelp = 'textDocument/signatureHelp',
  --- A request to resolve the type definition locations of a symbol at a given text
  --- document position. The request's parameter is of type [TextDocumentPositionParams]
  --- (#TextDocumentPositionParams) the response is of type {@link Definition} or a
  --- Thenable that resolves to such.
  textDocument_typeDefinition = 'textDocument/typeDefinition',
  --- A document will save notification is sent from the client to the server before
  --- the document is actually saved.
  textDocument_willSave = 'textDocument/willSave',
  --- A document will save request is sent from the client to the server before
  --- the document is actually saved. The request can return an array of TextEdits
  --- which will be applied to the text document before it is saved. Please note that
  --- clients might drop results if computing the text edits took too long or if a
  --- server constantly fails on this request. This is done to keep the save fast and
  --- reliable.
  textDocument_willSaveWaitUntil = 'textDocument/willSaveWaitUntil',
  --- A request to resolve the subtypes for a given `TypeHierarchyItem`.
  --- @since 3.17.0
  typeHierarchy_subtypes = 'typeHierarchy/subtypes',
  --- A request to resolve the supertypes for a given `TypeHierarchyItem`.
  --- @since 3.17.0
  typeHierarchy_supertypes = 'typeHierarchy/supertypes',
  --- The log message notification is sent from the server to the client to ask
  --- the client to log a particular message.
  window_logMessage = 'window/logMessage',
  --- A request to show a document. This request might open an
  --- external program depending on the value of the URI to open.
  --- For example a request to open `https://code.visualstudio.com/`
  --- will very likely open the URI in a WEB browser.
  --- @since 3.16.0
  window_showDocument = 'window/showDocument',
  --- The show message notification is sent from a server to a client to ask
  --- the client to display a particular message in the user interface.
  window_showMessage = 'window/showMessage',
  --- The show message request is sent from the server to the client to show a message
  --- and a set of options actions to the user.
  window_showMessageRequest = 'window/showMessageRequest',
  --- The `window/workDoneProgress/cancel` notification is sent from  the client to the server to cancel a progress
  --- initiated on the server side.
  window_workDoneProgress_cancel = 'window/workDoneProgress/cancel',
  --- The `window/workDoneProgress/create` request is sent from the server to the client to initiate progress
  --- reporting from the server.
  window_workDoneProgress_create = 'window/workDoneProgress/create',
  --- A request to resolve the range inside the workspace
  --- symbol's location.
  --- @since 3.17.0
  workspaceSymbol_resolve = 'workspaceSymbol/resolve',
  --- A request sent from the server to the client to modified certain resources.
  workspace_applyEdit = 'workspace/applyEdit',
  --- A request to refresh all code actions
  --- @since 3.16.0
  workspace_codeLens_refresh = 'workspace/codeLens/refresh',
  --- The 'workspace/configuration' request is sent from the server to the client to fetch a certain
  --- configuration setting.
  --- This pull model replaces the old push model were the client signaled configuration change via an
  --- event. If the server still needs to react to configuration changes (since the server caches the
  --- result of `workspace/configuration` requests) the server should register for an empty configuration
  --- change event and empty the cache if such an event is received.
  workspace_configuration = 'workspace/configuration',
  --- The workspace diagnostic request definition.
  --- @since 3.17.0
  workspace_diagnostic = 'workspace/diagnostic',
  --- The diagnostic refresh request definition.
  --- @since 3.17.0
  workspace_diagnostic_refresh = 'workspace/diagnostic/refresh',
  --- The configuration change notification is sent from the client to the server
  --- when the client's configuration has changed. The notification contains
  --- the changed configuration as defined by the language client.
  workspace_didChangeConfiguration = 'workspace/didChangeConfiguration',
  --- The watched files notification is sent from the client to the server when
  --- the client detects changes to file watched by the language client.
  workspace_didChangeWatchedFiles = 'workspace/didChangeWatchedFiles',
  --- The `workspace/didChangeWorkspaceFolders` notification is sent from the client to the server when the workspace
  --- folder configuration changes.
  workspace_didChangeWorkspaceFolders = 'workspace/didChangeWorkspaceFolders',
  --- The did create files notification is sent from the client to the server when
  --- files were created from within the client.
  --- @since 3.16.0
  workspace_didCreateFiles = 'workspace/didCreateFiles',
  --- The will delete files request is sent from the client to the server before files are actually
  --- deleted as long as the deletion is triggered from within the client.
  --- @since 3.16.0
  workspace_didDeleteFiles = 'workspace/didDeleteFiles',
  --- The did rename files notification is sent from the client to the server when
  --- files were renamed from within the client.
  --- @since 3.16.0
  workspace_didRenameFiles = 'workspace/didRenameFiles',
  --- A request send from the client to the server to execute a command. The request might return
  --- a workspace edit which the client will apply to the workspace.
  workspace_executeCommand = 'workspace/executeCommand',
  --- @since 3.17.0
  workspace_inlayHint_refresh = 'workspace/inlayHint/refresh',
  --- @since 3.17.0
  workspace_inlineValue_refresh = 'workspace/inlineValue/refresh',
  --- @since 3.16.0
  workspace_semanticTokens_refresh = 'workspace/semanticTokens/refresh',
  --- A request to list project-wide symbols matching the query string given
  --- by the {@link WorkspaceSymbolParams}. The response is
  --- of type {@link SymbolInformation SymbolInformation[]} or a Thenable that
  --- resolves to such.
  --- @since 3.17.0 - support for WorkspaceSymbol in the returned data. Clients
  ---  need to advertise support for WorkspaceSymbols via the client capability
  ---  `workspace.symbol.resolveSupport`.
  workspace_symbol = 'workspace/symbol',
  --- The will create files request is sent from the client to the server before files are actually
  --- created as long as the creation is triggered from within the client.
  --- The request can return a `WorkspaceEdit` which will be applied to workspace before the
  --- files are created. Hence the `WorkspaceEdit` can not manipulate the content of the file
  --- to be created.
  --- @since 3.16.0
  workspace_willCreateFiles = 'workspace/willCreateFiles',
  --- The did delete files notification is sent from the client to the server when
  --- files were deleted from within the client.
  --- @since 3.16.0
  workspace_willDeleteFiles = 'workspace/willDeleteFiles',
  --- The will rename files request is sent from the client to the server before files are actually
  --- renamed as long as the rename is triggered from within the client.
  --- @since 3.16.0
  workspace_willRenameFiles = 'workspace/willRenameFiles',
  --- The `workspace/workspaceFolders` is sent from the server to the client to fetch the open workspace folders.
  workspace_workspaceFolders = 'workspace/workspaceFolders',
}
local function freeze(t)
  return setmetatable({}, {
    __index = t,
    __newindex = function()
      error('cannot modify immutable table')
    end,
  })
end
protocol.Methods = freeze(protocol.Methods)

return protocol
