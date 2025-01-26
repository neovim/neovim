---@param tbl table<string|number, string|number>
local function get_value_set(tbl)
  local value_set = {}
  for k, v in pairs(tbl) do
    -- Because the input has reverse lookup entries, only look at the original
    -- pairs.
    if type(k) == 'string' then
      table.insert(value_set, v)
    end
  end
  table.sort(value_set)
  return value_set
end

local sysname = vim.uv.os_uname().sysname

--- Protocol for the Microsoft Language Server Protocol (mslsp)
--- @class vim.lsp.protocol
--- @nodoc
local protocol = {
  -- Completion item tags are extra annotations that tweak the rendering of a
  -- completion item
  CompletionTag = {
    -- Render a completion as obsolete, usually using a strike-out.
    Deprecated = 1,
  },
}

--- Gets a new ClientCapabilities object describing the LSP client
--- capabilities.
--- @return lsp.ClientCapabilities
function protocol.make_client_capabilities()
  return {
    general = {
      positionEncodings = {
        'utf-8',
        'utf-16',
        'utf-32',
      },
    },
    textDocument = {
      diagnostic = {
        dynamicRegistration = false,
      },
      inlayHint = {
        dynamicRegistration = true,
        resolveSupport = {
          properties = {
            'textEdits',
            'tooltip',
            'location',
            'command',
          },
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
            valueSet = get_value_set(protocol.CodeActionKind),
          },
        },
        isPreferredSupport = true,
        dataSupport = true,
        resolveSupport = {
          properties = { 'edit' },
        },
      },
      codeLens = {
        dynamicRegistration = false,
        resolveSupport = {
          properties = { 'command' },
        },
      },
      foldingRange = {
        dynamicRegistration = false,
        lineFoldingOnly = true,
        foldingRange = {
          collapsedText = true,
        },
      },
      formatting = {
        dynamicRegistration = true,
      },
      rangeFormatting = {
        dynamicRegistration = true,
        rangesSupport = true,
      },
      completion = {
        dynamicRegistration = false,
        completionItem = {
          snippetSupport = true,
          commitCharactersSupport = false,
          preselectSupport = false,
          deprecatedSupport = true,
          documentationFormat = { protocol.MarkupKind.Markdown, protocol.MarkupKind.PlainText },
          resolveSupport = {
            properties = {
              'additionalTextEdits',
            },
          },
          tagSupport = {
            valueSet = get_value_set(protocol.CompletionTag),
          },
        },
        completionItemKind = {
          valueSet = get_value_set(protocol.CompletionItemKind),
        },
        completionList = {
          itemDefaults = {
            'editRange',
            'insertTextFormat',
            'insertTextMode',
            'data',
          },
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
          valueSet = get_value_set(protocol.SymbolKind),
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
          valueSet = get_value_set(protocol.DiagnosticTag),
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
          valueSet = get_value_set(protocol.SymbolKind),
        },
      },
      configuration = true,
      didChangeConfiguration = {
        dynamicRegistration = false,
      },
      workspaceFolders = true,
      applyEdit = true,
      workspaceEdit = {
        resourceOperations = { 'rename', 'create', 'delete' },
      },
      semanticTokens = {
        refreshSupport = true,
      },
      didChangeWatchedFiles = {
        -- TODO(lewis6991): do not advertise didChangeWatchedFiles on Linux
        -- or BSD since all the current backends are too limited.
        -- Ref: #27807, #28058, #23291, #26520
        dynamicRegistration = sysname == 'Darwin' or sysname == 'Windows_NT',
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
          additionalPropertiesSupport = true,
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
---@return lsp.ServerCapabilities|nil : Normalized table of capabilities
function protocol.resolve_capabilities(server_capabilities)
  local TextDocumentSyncKind = protocol.TextDocumentSyncKind ---@type table<string|number, string|number>
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
---A set of predefined token types. This set is not fixed
---an clients can specify additional token types via the
---corresponding client capabilities.
---
---@since 3.16.0
---@nodoc
---@enum lsp.SemanticTokenTypes
protocol.SemanticTokenTypes = {
  ['namespace'] = 'namespace',
  ['type'] = 'type',
  ['class'] = 'class',
  ['enum'] = 'enum',
  ['interface'] = 'interface',
  ['struct'] = 'struct',
  ['typeParameter'] = 'typeParameter',
  ['parameter'] = 'parameter',
  ['variable'] = 'variable',
  ['property'] = 'property',
  ['enumMember'] = 'enumMember',
  ['event'] = 'event',
  ['function'] = 'function',
  ['method'] = 'method',
  ['macro'] = 'macro',
  ['keyword'] = 'keyword',
  ['modifier'] = 'modifier',
  ['comment'] = 'comment',
  ['string'] = 'string',
  ['number'] = 'number',
  ['regexp'] = 'regexp',
  ['operator'] = 'operator',
  ['decorator'] = 'decorator',
  ['label'] = 'label',
}

---A set of predefined token modifiers. This set is not fixed
---an clients can specify additional token types via the
---corresponding client capabilities.
---
---@since 3.16.0
---@nodoc
---@enum lsp.SemanticTokenModifiers
protocol.SemanticTokenModifiers = {
  ['declaration'] = 'declaration',
  ['definition'] = 'definition',
  ['readonly'] = 'readonly',
  ['static'] = 'static',
  ['deprecated'] = 'deprecated',
  ['abstract'] = 'abstract',
  ['async'] = 'async',
  ['modification'] = 'modification',
  ['documentation'] = 'documentation',
  ['defaultLibrary'] = 'defaultLibrary',
}

---The document diagnostic report kinds.
---
---@since 3.17.0
---@nodoc
---@enum lsp.DocumentDiagnosticReportKind
protocol.DocumentDiagnosticReportKind = {
  ['Full'] = 'full',
  ['Unchanged'] = 'unchanged',
}

---Predefined error codes.
---@nodoc
---@enum lsp.ErrorCodes
protocol.ErrorCodes = {
  ['ParseError'] = -32700,
  [-32700] = 'ParseError',
  ['InvalidRequest'] = -32600,
  [-32600] = 'InvalidRequest',
  ['MethodNotFound'] = -32601,
  [-32601] = 'MethodNotFound',
  ['InvalidParams'] = -32602,
  [-32602] = 'InvalidParams',
  ['InternalError'] = -32603,
  [-32603] = 'InternalError',
  ['ServerNotInitialized'] = -32002,
  [-32002] = 'ServerNotInitialized',
  ['UnknownErrorCode'] = -32001,
  [-32001] = 'UnknownErrorCode',
}

---@nodoc
---@enum lsp.LSPErrorCodes
protocol.LSPErrorCodes = {
  ['RequestFailed'] = -32803,
  [-32803] = 'RequestFailed',
  ['ServerCancelled'] = -32802,
  [-32802] = 'ServerCancelled',
  ['ContentModified'] = -32801,
  [-32801] = 'ContentModified',
  ['RequestCancelled'] = -32800,
  [-32800] = 'RequestCancelled',
}

---A set of predefined range kinds.
---@nodoc
---@enum lsp.FoldingRangeKind
protocol.FoldingRangeKind = {
  ['Comment'] = 'comment',
  ['Imports'] = 'imports',
  ['Region'] = 'region',
}

---A symbol kind.
---@nodoc
---@enum lsp.SymbolKind
protocol.SymbolKind = {
  ['File'] = 1,
  [1] = 'File',
  ['Module'] = 2,
  [2] = 'Module',
  ['Namespace'] = 3,
  [3] = 'Namespace',
  ['Package'] = 4,
  [4] = 'Package',
  ['Class'] = 5,
  [5] = 'Class',
  ['Method'] = 6,
  [6] = 'Method',
  ['Property'] = 7,
  [7] = 'Property',
  ['Field'] = 8,
  [8] = 'Field',
  ['Constructor'] = 9,
  [9] = 'Constructor',
  ['Enum'] = 10,
  [10] = 'Enum',
  ['Interface'] = 11,
  [11] = 'Interface',
  ['Function'] = 12,
  [12] = 'Function',
  ['Variable'] = 13,
  [13] = 'Variable',
  ['Constant'] = 14,
  [14] = 'Constant',
  ['String'] = 15,
  [15] = 'String',
  ['Number'] = 16,
  [16] = 'Number',
  ['Boolean'] = 17,
  [17] = 'Boolean',
  ['Array'] = 18,
  [18] = 'Array',
  ['Object'] = 19,
  [19] = 'Object',
  ['Key'] = 20,
  [20] = 'Key',
  ['Null'] = 21,
  [21] = 'Null',
  ['EnumMember'] = 22,
  [22] = 'EnumMember',
  ['Struct'] = 23,
  [23] = 'Struct',
  ['Event'] = 24,
  [24] = 'Event',
  ['Operator'] = 25,
  [25] = 'Operator',
  ['TypeParameter'] = 26,
  [26] = 'TypeParameter',
}

---Symbol tags are extra annotations that tweak the rendering of a symbol.
---
---@since 3.16
---@nodoc
---@enum lsp.SymbolTag
protocol.SymbolTag = {
  ['Deprecated'] = 1,
  [1] = 'Deprecated',
}

---Moniker uniqueness level to define scope of the moniker.
---
---@since 3.16.0
---@nodoc
---@enum lsp.UniquenessLevel
protocol.UniquenessLevel = {
  ['document'] = 'document',
  ['project'] = 'project',
  ['group'] = 'group',
  ['scheme'] = 'scheme',
  ['global'] = 'global',
}

---The moniker kind.
---
---@since 3.16.0
---@nodoc
---@enum lsp.MonikerKind
protocol.MonikerKind = {
  ['import'] = 'import',
  ['export'] = 'export',
  ['local'] = 'local',
}

---Inlay hint kinds.
---
---@since 3.17.0
---@nodoc
---@enum lsp.InlayHintKind
protocol.InlayHintKind = {
  ['Type'] = 1,
  [1] = 'Type',
  ['Parameter'] = 2,
  [2] = 'Parameter',
}

---The message type
---@nodoc
---@enum lsp.MessageType
protocol.MessageType = {
  ['Error'] = 1,
  [1] = 'Error',
  ['Warning'] = 2,
  [2] = 'Warning',
  ['Info'] = 3,
  [3] = 'Info',
  ['Log'] = 4,
  [4] = 'Log',
  ['Debug'] = 5,
  [5] = 'Debug',
}

---Defines how the host (editor) should sync
---document changes to the language server.
---@nodoc
---@enum lsp.TextDocumentSyncKind
protocol.TextDocumentSyncKind = {
  ['None'] = 0,
  [0] = 'None',
  ['Full'] = 1,
  [1] = 'Full',
  ['Incremental'] = 2,
  [2] = 'Incremental',
}

---Represents reasons why a text document is saved.
---@nodoc
---@enum lsp.TextDocumentSaveReason
protocol.TextDocumentSaveReason = {
  ['Manual'] = 1,
  [1] = 'Manual',
  ['AfterDelay'] = 2,
  [2] = 'AfterDelay',
  ['FocusOut'] = 3,
  [3] = 'FocusOut',
}

---The kind of a completion entry.
---@nodoc
---@enum lsp.CompletionItemKind
protocol.CompletionItemKind = {
  ['Text'] = 1,
  [1] = 'Text',
  ['Method'] = 2,
  [2] = 'Method',
  ['Function'] = 3,
  [3] = 'Function',
  ['Constructor'] = 4,
  [4] = 'Constructor',
  ['Field'] = 5,
  [5] = 'Field',
  ['Variable'] = 6,
  [6] = 'Variable',
  ['Class'] = 7,
  [7] = 'Class',
  ['Interface'] = 8,
  [8] = 'Interface',
  ['Module'] = 9,
  [9] = 'Module',
  ['Property'] = 10,
  [10] = 'Property',
  ['Unit'] = 11,
  [11] = 'Unit',
  ['Value'] = 12,
  [12] = 'Value',
  ['Enum'] = 13,
  [13] = 'Enum',
  ['Keyword'] = 14,
  [14] = 'Keyword',
  ['Snippet'] = 15,
  [15] = 'Snippet',
  ['Color'] = 16,
  [16] = 'Color',
  ['File'] = 17,
  [17] = 'File',
  ['Reference'] = 18,
  [18] = 'Reference',
  ['Folder'] = 19,
  [19] = 'Folder',
  ['EnumMember'] = 20,
  [20] = 'EnumMember',
  ['Constant'] = 21,
  [21] = 'Constant',
  ['Struct'] = 22,
  [22] = 'Struct',
  ['Event'] = 23,
  [23] = 'Event',
  ['Operator'] = 24,
  [24] = 'Operator',
  ['TypeParameter'] = 25,
  [25] = 'TypeParameter',
}

---Completion item tags are extra annotations that tweak the rendering of a completion
---item.
---
---@since 3.15.0
---@nodoc
---@enum lsp.CompletionItemTag
protocol.CompletionItemTag = {
  ['Deprecated'] = 1,
  [1] = 'Deprecated',
}

---Defines whether the insert text in a completion item should be interpreted as
---plain text or a snippet.
---@nodoc
---@enum lsp.InsertTextFormat
protocol.InsertTextFormat = {
  ['PlainText'] = 1,
  [1] = 'PlainText',
  ['Snippet'] = 2,
  [2] = 'Snippet',
}

---How whitespace and indentation is handled during completion
---item insertion.
---
---@since 3.16.0
---@nodoc
---@enum lsp.InsertTextMode
protocol.InsertTextMode = {
  ['asIs'] = 1,
  [1] = 'asIs',
  ['adjustIndentation'] = 2,
  [2] = 'adjustIndentation',
}

---A document highlight kind.
---@nodoc
---@enum lsp.DocumentHighlightKind
protocol.DocumentHighlightKind = {
  ['Text'] = 1,
  [1] = 'Text',
  ['Read'] = 2,
  [2] = 'Read',
  ['Write'] = 3,
  [3] = 'Write',
}

---A set of predefined code action kinds
---@nodoc
---@enum lsp.CodeActionKind
protocol.CodeActionKind = {
  ['Empty'] = '',
  ['QuickFix'] = 'quickfix',
  ['Refactor'] = 'refactor',
  ['RefactorExtract'] = 'refactor.extract',
  ['RefactorInline'] = 'refactor.inline',
  ['RefactorMove'] = 'refactor.move',
  ['RefactorRewrite'] = 'refactor.rewrite',
  ['Source'] = 'source',
  ['SourceOrganizeImports'] = 'source.organizeImports',
  ['SourceFixAll'] = 'source.fixAll',
  ['Notebook'] = 'notebook',
}

---Code action tags are extra annotations that tweak the behavior of a code action.
---
---@since 3.18.0 - proposed
---@nodoc
---@enum lsp.CodeActionTag
protocol.CodeActionTag = {
  ['LLMGenerated'] = 1,
  [1] = 'LLMGenerated',
}

---@nodoc
---@enum lsp.TraceValue
protocol.TraceValue = {
  ['Off'] = 'off',
  ['Messages'] = 'messages',
  ['Verbose'] = 'verbose',
}

---Describes the content type that a client supports in various
---result literals like `Hover`, `ParameterInfo` or `CompletionItem`.
---
---Please note that `MarkupKinds` must not start with a `$`. This kinds
---are reserved for internal usage.
---@nodoc
---@enum lsp.MarkupKind
protocol.MarkupKind = {
  ['PlainText'] = 'plaintext',
  ['Markdown'] = 'markdown',
}

---Predefined Language kinds
---@since 3.18.0
---@proposed
---@nodoc
---@enum lsp.LanguageKind
protocol.LanguageKind = {
  ['ABAP'] = 'abap',
  ['WindowsBat'] = 'bat',
  ['BibTeX'] = 'bibtex',
  ['Clojure'] = 'clojure',
  ['Coffeescript'] = 'coffeescript',
  ['C'] = 'c',
  ['CPP'] = 'cpp',
  ['CSharp'] = 'csharp',
  ['CSS'] = 'css',
  ['D'] = 'd',
  ['Delphi'] = 'pascal',
  ['Diff'] = 'diff',
  ['Dart'] = 'dart',
  ['Dockerfile'] = 'dockerfile',
  ['Elixir'] = 'elixir',
  ['Erlang'] = 'erlang',
  ['FSharp'] = 'fsharp',
  ['GitCommit'] = 'git-commit',
  ['GitRebase'] = 'rebase',
  ['Go'] = 'go',
  ['Groovy'] = 'groovy',
  ['Handlebars'] = 'handlebars',
  ['Haskell'] = 'haskell',
  ['HTML'] = 'html',
  ['Ini'] = 'ini',
  ['Java'] = 'java',
  ['JavaScript'] = 'javascript',
  ['JavaScriptReact'] = 'javascriptreact',
  ['JSON'] = 'json',
  ['LaTeX'] = 'latex',
  ['Less'] = 'less',
  ['Lua'] = 'lua',
  ['Makefile'] = 'makefile',
  ['Markdown'] = 'markdown',
  ['ObjectiveC'] = 'objective-c',
  ['ObjectiveCPP'] = 'objective-cpp',
  ['Pascal'] = 'pascal',
  ['Perl'] = 'perl',
  ['Perl6'] = 'perl6',
  ['PHP'] = 'php',
  ['Powershell'] = 'powershell',
  ['Pug'] = 'jade',
  ['Python'] = 'python',
  ['R'] = 'r',
  ['Razor'] = 'razor',
  ['Ruby'] = 'ruby',
  ['Rust'] = 'rust',
  ['SCSS'] = 'scss',
  ['SASS'] = 'sass',
  ['Scala'] = 'scala',
  ['ShaderLab'] = 'shaderlab',
  ['ShellScript'] = 'shellscript',
  ['SQL'] = 'sql',
  ['Swift'] = 'swift',
  ['TypeScript'] = 'typescript',
  ['TypeScriptReact'] = 'typescriptreact',
  ['TeX'] = 'tex',
  ['VisualBasic'] = 'vb',
  ['XML'] = 'xml',
  ['XSL'] = 'xsl',
  ['YAML'] = 'yaml',
}

---Describes how an {@link InlineCompletionItemProvider inline completion provider} was triggered.
---
---@since 3.18.0
---@proposed
---@nodoc
---@enum lsp.InlineCompletionTriggerKind
protocol.InlineCompletionTriggerKind = {
  ['Invoked'] = 1,
  [1] = 'Invoked',
  ['Automatic'] = 2,
  [2] = 'Automatic',
}

---A set of predefined position encoding kinds.
---
---@since 3.17.0
---@nodoc
---@enum lsp.PositionEncodingKind
protocol.PositionEncodingKind = {
  ['UTF8'] = 'utf-8',
  ['UTF16'] = 'utf-16',
  ['UTF32'] = 'utf-32',
}

---The file event type
---@nodoc
---@enum lsp.FileChangeType
protocol.FileChangeType = {
  ['Created'] = 1,
  [1] = 'Created',
  ['Changed'] = 2,
  [2] = 'Changed',
  ['Deleted'] = 3,
  [3] = 'Deleted',
}

---@nodoc
---@enum lsp.WatchKind
protocol.WatchKind = {
  ['Create'] = 1,
  [1] = 'Create',
  ['Change'] = 2,
  [2] = 'Change',
  ['Delete'] = 4,
  [4] = 'Delete',
}

---The diagnostic's severity.
---@nodoc
---@enum lsp.DiagnosticSeverity
protocol.DiagnosticSeverity = {
  ['Error'] = 1,
  [1] = 'Error',
  ['Warning'] = 2,
  [2] = 'Warning',
  ['Information'] = 3,
  [3] = 'Information',
  ['Hint'] = 4,
  [4] = 'Hint',
}

---The diagnostic tags.
---
---@since 3.15.0
---@nodoc
---@enum lsp.DiagnosticTag
protocol.DiagnosticTag = {
  ['Unnecessary'] = 1,
  [1] = 'Unnecessary',
  ['Deprecated'] = 2,
  [2] = 'Deprecated',
}

---How a completion was triggered
---@nodoc
---@enum lsp.CompletionTriggerKind
protocol.CompletionTriggerKind = {
  ['Invoked'] = 1,
  [1] = 'Invoked',
  ['TriggerCharacter'] = 2,
  [2] = 'TriggerCharacter',
  ['TriggerForIncompleteCompletions'] = 3,
  [3] = 'TriggerForIncompleteCompletions',
}

---How a signature help was triggered.
---
---@since 3.15.0
---@nodoc
---@enum lsp.SignatureHelpTriggerKind
protocol.SignatureHelpTriggerKind = {
  ['Invoked'] = 1,
  [1] = 'Invoked',
  ['TriggerCharacter'] = 2,
  [2] = 'TriggerCharacter',
  ['ContentChange'] = 3,
  [3] = 'ContentChange',
}

---The reason why code actions were requested.
---
---@since 3.17.0
---@nodoc
---@enum lsp.CodeActionTriggerKind
protocol.CodeActionTriggerKind = {
  ['Invoked'] = 1,
  [1] = 'Invoked',
  ['Automatic'] = 2,
  [2] = 'Automatic',
}

---A pattern kind describing if a glob pattern matches a file a folder or
---both.
---
---@since 3.16.0
---@nodoc
---@enum lsp.FileOperationPatternKind
protocol.FileOperationPatternKind = {
  ['file'] = 'file',
  ['folder'] = 'folder',
}

---A notebook cell kind.
---
---@since 3.17.0
---@nodoc
---@enum lsp.NotebookCellKind
protocol.NotebookCellKind = {
  ['Markup'] = 1,
  [1] = 'Markup',
  ['Code'] = 2,
  [2] = 'Code',
}

---@nodoc
---@enum lsp.ResourceOperationKind
protocol.ResourceOperationKind = {
  ['Create'] = 'create',
  ['Rename'] = 'rename',
  ['Delete'] = 'delete',
}

---@nodoc
---@enum lsp.FailureHandlingKind
protocol.FailureHandlingKind = {
  ['Abort'] = 'abort',
  ['Transactional'] = 'transactional',
  ['TextOnlyTransactional'] = 'textOnlyTransactional',
  ['Undo'] = 'undo',
}

---@nodoc
---@enum lsp.PrepareSupportDefaultBehavior
protocol.PrepareSupportDefaultBehavior = {
  ['Identifier'] = 1,
  [1] = 'Identifier',
}

---@nodoc
---@enum lsp.TokenFormat
protocol.TokenFormat = {
  ['Relative'] = 'relative',
}

--- @alias vim.lsp.protocol.Method.ClientToServer
--- | 'callHierarchy/incomingCalls',
--- | 'callHierarchy/outgoingCalls',
--- | 'codeAction/resolve',
--- | 'codeLens/resolve',
--- | 'completionItem/resolve',
--- | 'documentLink/resolve',
--- | '$/setTrace',
--- | 'exit',
--- | 'initialize',
--- | 'initialized',
--- | 'inlayHint/resolve',
--- | 'notebookDocument/didChange',
--- | 'notebookDocument/didClose',
--- | 'notebookDocument/didOpen',
--- | 'notebookDocument/didSave',
--- | 'shutdown',
--- | 'textDocument/codeAction',
--- | 'textDocument/codeLens',
--- | 'textDocument/colorPresentation',
--- | 'textDocument/completion',
--- | 'textDocument/declaration',
--- | 'textDocument/definition',
--- | 'textDocument/diagnostic',
--- | 'textDocument/didChange',
--- | 'textDocument/didClose',
--- | 'textDocument/didOpen',
--- | 'textDocument/didSave',
--- | 'textDocument/documentColor',
--- | 'textDocument/documentHighlight',
--- | 'textDocument/documentLink',
--- | 'textDocument/documentSymbol',
--- | 'textDocument/foldingRange',
--- | 'textDocument/formatting',
--- | 'textDocument/hover',
--- | 'textDocument/implementation',
--- | 'textDocument/inlayHint',
--- | 'textDocument/inlineCompletion',
--- | 'textDocument/inlineValue',
--- | 'textDocument/linkedEditingRange',
--- | 'textDocument/moniker',
--- | 'textDocument/onTypeFormatting',
--- | 'textDocument/prepareCallHierarchy',
--- | 'textDocument/prepareRename',
--- | 'textDocument/prepareTypeHierarchy',
--- | 'textDocument/rangeFormatting',
--- | 'textDocument/rangesFormatting',
--- | 'textDocument/references',
--- | 'textDocument/rename',
--- | 'textDocument/selectionRange',
--- | 'textDocument/semanticTokens/full',
--- | 'textDocument/semanticTokens/full/delta',
--- | 'textDocument/semanticTokens/range',
--- | 'textDocument/signatureHelp',
--- | 'textDocument/typeDefinition',
--- | 'textDocument/willSave',
--- | 'textDocument/willSaveWaitUntil',
--- | 'typeHierarchy/subtypes',
--- | 'typeHierarchy/supertypes',
--- | 'window/workDoneProgress/cancel',
--- | 'workspaceSymbol/resolve',
--- | 'workspace/diagnostic',
--- | 'workspace/didChangeConfiguration',
--- | 'workspace/didChangeWatchedFiles',
--- | 'workspace/didChangeWorkspaceFolders',
--- | 'workspace/didCreateFiles',
--- | 'workspace/didDeleteFiles',
--- | 'workspace/didRenameFiles',
--- | 'workspace/executeCommand',
--- | 'workspace/symbol',
--- | 'workspace/willCreateFiles',
--- | 'workspace/willDeleteFiles',
--- | 'workspace/willRenameFiles',

--- @alias vim.lsp.protocol.Method.ServerToClient
--- | 'client/registerCapability',
--- | 'client/unregisterCapability',
--- | '$/logTrace',
--- | 'telemetry/event',
--- | 'textDocument/publishDiagnostics',
--- | 'window/logMessage',
--- | 'window/showDocument',
--- | 'window/showMessage',
--- | 'window/showMessageRequest',
--- | 'window/workDoneProgress/create',
--- | 'workspace/applyEdit',
--- | 'workspace/codeLens/refresh',
--- | 'workspace/configuration',
--- | 'workspace/diagnostic/refresh',
--- | 'workspace/foldingRange/refresh',
--- | 'workspace/inlayHint/refresh',
--- | 'workspace/inlineValue/refresh',
--- | 'workspace/semanticTokens/refresh',
--- | 'workspace/workspaceFolders',

--- @alias vim.lsp.protocol.Method
--- | vim.lsp.protocol.Method.ClientToServer
--- | vim.lsp.protocol.Method.ServerToClient

--- @enum vim.lsp.protocol.Methods
--- @see https://microsoft.github.io/language-server-protocol/specification/#metaModel
--- LSP method names.
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
  --- document position. The request's parameter is of type {@link TextDocumentPositionParams}
  --- the response is of type {@link Declaration} or a typed array of {@link DeclarationLink}
  --- or a Thenable that resolves to such.
  textDocument_declaration = 'textDocument/declaration',
  --- A request to resolve the definition location of a symbol at a given text
  --- document position. The request's parameter is of type {@link TextDocumentPosition}
  --- the response is of either type {@link Definition} or a typed array of
  --- {@link DefinitionLink} or a Thenable that resolves to such.
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
  --- text document position. The request's parameter is of type {@link TextDocumentPosition}
  --- the request response is an array of type {@link DocumentHighlight}
  --- or a Thenable that resolves to such.
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
  --- A request to format a whole document.
  textDocument_formatting = 'textDocument/formatting',
  --- Request to request hover information at a given text document position. The request's
  --- parameter is of type {@link TextDocumentPosition} the response is of
  --- type {@link Hover} or a Thenable that resolves to such.
  textDocument_hover = 'textDocument/hover',
  --- A request to resolve the implementation locations of a symbol at a given text
  --- document position. The request's parameter is of type {@link TextDocumentPositionParams}
  --- the response is of type {@link Definition} or a Thenable that resolves to such.
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
  --- @proposed
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
  --- document position. The request's parameter is of type {@link TextDocumentPositionParams}
  --- the response is of type {@link Definition} or a Thenable that resolves to such.
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
  --- @since 3.18.0
  --- @proposed
  workspace_foldingRange_refresh = 'workspace/foldingRange/refresh',
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

return protocol
