-- Protocol for the Microsoft Language Server Protocol (mslsp)

local if_nil = vim.F.if_nil

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

  DiagnosticTag = {
    -- Unused or unnecessary code
    Unnecessary = 1;
    -- Deprecated or obsolete code
    Deprecated = 2;
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
function protocol.make_client_capabilities()
  return {
    textDocument = {
      synchronization = {
        dynamicRegistration = false;

        -- TODO(ashkan) Send textDocument/willSave before saving (BufWritePre)
        willSave = false;

        -- TODO(ashkan) Implement textDocument/willSaveWaitUntil
        willSaveWaitUntil = false;

        -- Send textDocument/didSave after saving (BufWritePost)
        didSave = true;
      };
      codeAction = {
        dynamicRegistration = false;

        codeActionLiteralSupport = {
          codeActionKind = {
            valueSet = (function()
              local res = vim.tbl_values(protocol.CodeActionKind)
              table.sort(res)
              return res
            end)();
          };
        };
        dataSupport = true;
        resolveSupport = {
          properties = { 'edit', }
        };
      };
      completion = {
        dynamicRegistration = false;
        completionItem = {
          -- Until we can actually expand snippet, move cursor and allow for true snippet experience,
          -- this should be disabled out of the box.
          -- However, users can turn this back on if they have a snippet plugin.
          snippetSupport = false;

          commitCharactersSupport = false;
          preselectSupport = false;
          deprecatedSupport = false;
          documentationFormat = { protocol.MarkupKind.Markdown; protocol.MarkupKind.PlainText };
        };
        completionItemKind = {
          valueSet = (function()
            local res = {}
            for k in ipairs(protocol.CompletionItemKind) do
              if type(k) == 'number' then table.insert(res, k) end
            end
            return res
          end)();
        };

        -- TODO(tjdevries): Implement this
        contextSupport = false;
      };
      declaration = {
        linkSupport = true;
      };
      definition = {
        linkSupport = true;
      };
      implementation = {
        linkSupport = true;
      };
      typeDefinition = {
        linkSupport = true;
      };
      hover = {
        dynamicRegistration = false;
        contentFormat = { protocol.MarkupKind.Markdown; protocol.MarkupKind.PlainText };
      };
      signatureHelp = {
        dynamicRegistration = false;
        signatureInformation = {
          activeParameterSupport = true;
          documentationFormat = { protocol.MarkupKind.Markdown; protocol.MarkupKind.PlainText };
          parameterInformation = {
            labelOffsetSupport = true;
          };
        };
      };
      references = {
        dynamicRegistration = false;
      };
      documentHighlight = {
        dynamicRegistration = false
      };
      documentSymbol = {
        dynamicRegistration = false;
        symbolKind = {
          valueSet = (function()
            local res = {}
            for k in ipairs(protocol.SymbolKind) do
              if type(k) == 'number' then table.insert(res, k) end
            end
            return res
          end)();
        };
        hierarchicalDocumentSymbolSupport = true;
      };
      rename = {
        dynamicRegistration = false;
        prepareSupport = true;
      };
      publishDiagnostics = {
        relatedInformation = true;
        tagSupport = {
          valueSet = (function()
            local res = {}
            for k in ipairs(protocol.DiagnosticTag) do
              if type(k) == 'number' then table.insert(res, k) end
            end
            return res
          end)();
        };
      };
    };
    workspace = {
      symbol = {
        dynamicRegistration = false;
        symbolKind = {
          valueSet = (function()
            local res = {}
            for k in ipairs(protocol.SymbolKind) do
              if type(k) == 'number' then table.insert(res, k) end
            end
            return res
          end)();
        };
        hierarchicalWorkspaceSymbolSupport = true;
      };
      workspaceFolders = true;
      applyEdit = true;
      workspaceEdit = {
        resourceOperations = {'rename', 'create', 'delete',},
      };
    };
    callHierarchy = {
      dynamicRegistration = false;
    };
    experimental = nil;
    window = {
      workDoneProgress = true;
      showMessage = {
        messageActionItem = {
          additionalPropertiesSupport = false;
        };
      };
      showDocument = {
        support = false;
      };
    };
  }
end

--[=[
export interface DocumentFilter {
  --A language id, like `typescript`.
  language?: string;
  --A Uri [scheme](#Uri.scheme), like `file` or `untitled`.
  scheme?: string;
  --A glob pattern, like `*.{ts,js}`.
  --
  --Glob patterns can have the following syntax:
  --- `*` to match one or more characters in a path segment
  --- `?` to match on one character in a path segment
  --- `**` to match any number of path segments, including none
  --- `{}` to group conditions (e.g. `**​/*.{ts,js}` matches all TypeScript and JavaScript files)
  --- `[]` to declare a range of characters to match in a path segment (e.g., `example.[0-9]` to match on `example.0`, `example.1`, …)
  --- `[!...]` to negate a range of characters to match in a path segment (e.g., `example.[!0-9]` to match on `example.a`, `example.b`, but not `example.0`)
  pattern?: string;
}
--]=]

--[[
--Static registration options to be returned in the initialize request.
interface StaticRegistrationOptions {
  --The id used to register the request. The id can be used to deregister
  --the request again. See also Registration#id.
  id?: string;
}

export interface DocumentFilter {
  --A language id, like `typescript`.
  language?: string;
  --A Uri [scheme](#Uri.scheme), like `file` or `untitled`.
  scheme?: string;
  --A glob pattern, like `*.{ts,js}`.
  --
  --Glob patterns can have the following syntax:
  --- `*` to match one or more characters in a path segment
  --- `?` to match on one character in a path segment
  --- `**` to match any number of path segments, including none
  --- `{}` to group conditions (e.g. `**​/*.{ts,js}` matches all TypeScript and JavaScript files)
  --- `[]` to declare a range of characters to match in a path segment (e.g., `example.[0-9]` to match on `example.0`, `example.1`, …)
  --- `[!...]` to negate a range of characters to match in a path segment (e.g., `example.[!0-9]` to match on `example.a`, `example.b`, but not `example.0`)
  pattern?: string;
}
export type DocumentSelector = DocumentFilter[];
export interface TextDocumentRegistrationOptions {
  --A document selector to identify the scope of the registration. If set to null
  --the document selector provided on the client side will be used.
  documentSelector: DocumentSelector | null;
}

--Code Action options.
export interface CodeActionOptions {
  --CodeActionKinds that this server may return.
  --
  --The list of kinds may be generic, such as `CodeActionKind.Refactor`, or the server
  --may list out every specific kind they provide.
  codeActionKinds?: CodeActionKind[];
}

interface ServerCapabilities {
  --Defines how text documents are synced. Is either a detailed structure defining each notification or
  --for backwards compatibility the TextDocumentSyncKind number. If omitted it defaults to `TextDocumentSyncKind.None`.
  textDocumentSync?: TextDocumentSyncOptions | number;
  --The server provides hover support.
  hoverProvider?: boolean;
  --The server provides completion support.
  completionProvider?: CompletionOptions;
  --The server provides signature help support.
  signatureHelpProvider?: SignatureHelpOptions;
  --The server provides goto definition support.
  definitionProvider?: boolean;
  --The server provides Goto Type Definition support.
  --
  --Since 3.6.0
  typeDefinitionProvider?: boolean | (TextDocumentRegistrationOptions & StaticRegistrationOptions);
  --The server provides Goto Implementation support.
  --
  --Since 3.6.0
  implementationProvider?: boolean | (TextDocumentRegistrationOptions & StaticRegistrationOptions);
  --The server provides find references support.
  referencesProvider?: boolean;
  --The server provides document highlight support.
  documentHighlightProvider?: boolean;
  --The server provides document symbol support.
  documentSymbolProvider?: boolean;
  --The server provides workspace symbol support.
  workspaceSymbolProvider?: boolean;
  --The server provides code actions. The `CodeActionOptions` return type is only
  --valid if the client signals code action literal support via the property
  --`textDocument.codeAction.codeActionLiteralSupport`.
  codeActionProvider?: boolean | CodeActionOptions;
  --The server provides code lens.
  codeLensProvider?: CodeLensOptions;
  --The server provides document formatting.
  documentFormattingProvider?: boolean;
  --The server provides document range formatting.
  documentRangeFormattingProvider?: boolean;
  --The server provides document formatting on typing.
  documentOnTypeFormattingProvider?: DocumentOnTypeFormattingOptions;
  --The server provides rename support. RenameOptions may only be
  --specified if the client states that it supports
  --`prepareSupport` in its initial `initialize` request.
  renameProvider?: boolean | RenameOptions;
  --The server provides document link support.
  documentLinkProvider?: DocumentLinkOptions;
  --The server provides color provider support.
  --
  --Since 3.6.0
  colorProvider?: boolean | ColorProviderOptions | (ColorProviderOptions & TextDocumentRegistrationOptions & StaticRegistrationOptions);
  --The server provides folding provider support.
  --
  --Since 3.10.0
  foldingRangeProvider?: boolean | FoldingRangeProviderOptions | (FoldingRangeProviderOptions & TextDocumentRegistrationOptions & StaticRegistrationOptions);
  --The server provides go to declaration support.
  --
  --Since 3.14.0
  declarationProvider?: boolean | (TextDocumentRegistrationOptions & StaticRegistrationOptions);
  --The server provides execute command support.
  executeCommandProvider?: ExecuteCommandOptions;
  --Workspace specific server capabilities
  workspace?: {
    --The server supports workspace folder.
    --
    --Since 3.6.0
    workspaceFolders?: {
      * The server has support for workspace folders
      supported?: boolean;
      * Whether the server wants to receive workspace folder
      * change notifications.
      *
      * If a strings is provided the string is treated as a ID
      * under which the notification is registered on the client
      * side. The ID can be used to unregister for these events
      * using the `client/unregisterCapability` request.
      changeNotifications?: string | boolean;
    }
  }
  --Experimental server capabilities.
  experimental?: any;
}
--]]

--- Creates a normalized object describing LSP server capabilities.
function protocol.resolve_capabilities(server_capabilities)
  local general_properties = {}
  local text_document_sync_properties
  do
    local TextDocumentSyncKind = protocol.TextDocumentSyncKind
    local textDocumentSync = server_capabilities.textDocumentSync
    if textDocumentSync == nil then
      -- Defaults if omitted.
      text_document_sync_properties = {
        text_document_open_close = false;
        text_document_did_change = TextDocumentSyncKind.None;
--        text_document_did_change = false;
        text_document_will_save = false;
        text_document_will_save_wait_until = false;
        text_document_save = false;
        text_document_save_include_text = false;
      }
    elseif type(textDocumentSync) == 'number' then
      -- Backwards compatibility
      if not TextDocumentSyncKind[textDocumentSync] then
        return nil, "Invalid server TextDocumentSyncKind for textDocumentSync"
      end
      text_document_sync_properties = {
        text_document_open_close = true;
        text_document_did_change = textDocumentSync;
        text_document_will_save = false;
        text_document_will_save_wait_until = false;
        text_document_save = true;
        text_document_save_include_text = false;
      }
    elseif type(textDocumentSync) == 'table' then
      text_document_sync_properties = {
        text_document_open_close = if_nil(textDocumentSync.openClose, false);
        text_document_did_change = if_nil(textDocumentSync.change, TextDocumentSyncKind.None);
        text_document_will_save = if_nil(textDocumentSync.willSave, false);
        text_document_will_save_wait_until = if_nil(textDocumentSync.willSaveWaitUntil, false);
        text_document_save = if_nil(textDocumentSync.save, false);
        text_document_save_include_text = if_nil(type(textDocumentSync.save) == 'table'
                                                and textDocumentSync.save.includeText, false);
      }
    else
      return nil, string.format("Invalid type for textDocumentSync: %q", type(textDocumentSync))
    end
  end
  general_properties.completion = server_capabilities.completionProvider ~= nil
  general_properties.hover = server_capabilities.hoverProvider or false
  general_properties.goto_definition = server_capabilities.definitionProvider or false
  general_properties.find_references = server_capabilities.referencesProvider or false
  general_properties.document_highlight = server_capabilities.documentHighlightProvider or false
  general_properties.document_symbol = server_capabilities.documentSymbolProvider or false
  general_properties.workspace_symbol = server_capabilities.workspaceSymbolProvider or false
  general_properties.document_formatting = server_capabilities.documentFormattingProvider or false
  general_properties.document_range_formatting = server_capabilities.documentRangeFormattingProvider or false
  general_properties.call_hierarchy = server_capabilities.callHierarchyProvider or false
  general_properties.execute_command = server_capabilities.executeCommandProvider ~= nil

  if server_capabilities.renameProvider == nil then
    general_properties.rename = false
  elseif type(server_capabilities.renameProvider) == 'boolean' then
    general_properties.rename = server_capabilities.renameProvider
  else
    general_properties.rename = true
  end

  if server_capabilities.codeLensProvider == nil then
    general_properties.code_lens = false
    general_properties.code_lens_resolve = false
  elseif type(server_capabilities.codeLensProvider) == 'table' then
    general_properties.code_lens = true
    general_properties.code_lens_resolve = server_capabilities.codeLensProvider.resolveProvider or false
  else
    error("The server sent invalid codeLensProvider")
  end

  if server_capabilities.codeActionProvider == nil then
    general_properties.code_action = false
  elseif type(server_capabilities.codeActionProvider) == 'boolean'
    or type(server_capabilities.codeActionProvider) == 'table' then
    general_properties.code_action = server_capabilities.codeActionProvider
  else
    error("The server sent invalid codeActionProvider")
  end

  if server_capabilities.declarationProvider == nil then
    general_properties.declaration = false
  elseif type(server_capabilities.declarationProvider) == 'boolean' then
    general_properties.declaration = server_capabilities.declarationProvider
  elseif type(server_capabilities.declarationProvider) == 'table' then
    general_properties.declaration = server_capabilities.declarationProvider
  else
    error("The server sent invalid declarationProvider")
  end

  if server_capabilities.typeDefinitionProvider == nil then
    general_properties.type_definition = false
  elseif type(server_capabilities.typeDefinitionProvider) == 'boolean' then
    general_properties.type_definition = server_capabilities.typeDefinitionProvider
  elseif type(server_capabilities.typeDefinitionProvider) == 'table' then
    general_properties.type_definition = server_capabilities.typeDefinitionProvider
  else
    error("The server sent invalid typeDefinitionProvider")
  end

  if server_capabilities.implementationProvider == nil then
    general_properties.implementation = false
  elseif type(server_capabilities.implementationProvider) == 'boolean' then
    general_properties.implementation = server_capabilities.implementationProvider
  elseif type(server_capabilities.implementationProvider) == 'table' then
    general_properties.implementation = server_capabilities.implementationProvider
  else
    error("The server sent invalid implementationProvider")
  end

  local workspace = server_capabilities.workspace
  local workspace_properties = {}
  if workspace == nil or workspace.workspaceFolders == nil then
    -- Defaults if omitted.
    workspace_properties = {
      workspace_folder_properties =  {
        supported = false;
        changeNotifications=false;
      }
    }
  elseif type(workspace.workspaceFolders) == 'table' then
    workspace_properties = {
      workspace_folder_properties = {
        supported = if_nil(workspace.workspaceFolders.supported, false);
        changeNotifications = if_nil(workspace.workspaceFolders.changeNotifications, false);

      }
    }
  else
    error("The server sent invalid workspace")
  end

  local signature_help_properties
  if server_capabilities.signatureHelpProvider == nil then
    signature_help_properties = {
      signature_help = false;
      signature_help_trigger_characters = {};
    }
  elseif type(server_capabilities.signatureHelpProvider) == 'table' then
    signature_help_properties = {
      signature_help = true;
      -- The characters that trigger signature help automatically.
      signature_help_trigger_characters = server_capabilities.signatureHelpProvider.triggerCharacters or {};
    }
  else
    error("The server sent invalid signatureHelpProvider")
  end

  return vim.tbl_extend("error"
      , text_document_sync_properties
      , signature_help_properties
      , workspace_properties
      , general_properties
      )
end

return protocol
-- vim:sw=2 ts=2 et
