---@meta

---@alias lsp-handler fun(err: lsp.ResponseError|nil, result: any, context: lsp.HandlerContext, config: table|nil): any?

---@class lsp.HandlerContext
---@field method string
---@field client_id integer
---@field bufnr integer
---@field params any

---@class lsp.ResponseError
---@field code integer
---@field message string
---@field data string|number|boolean|table[]|table|nil

---@class lsp.ShowMessageRequestParams
---@field type lsp.MessageType
---@field message string
---@field actions nil|lsp.MessageActionItem[]

---@class lsp.MessageActionItem
---@field title string

---@class lsp.FileEvent
---@field uri string
---@field type lsp.FileChangeType

---@class lsp.Position
---@field line integer
---@field character integer

---@class lsp.Range
---@field start lsp.Position
---@field end lsp.Position

---@class lsp.Diagnostic
---@field range lsp.Range
---@field message string
---@field severity? lsp.DiagnosticSeverity
---@field code integer | string
---@field source string
---@field tags? lsp.DiagnosticTag[]
---@field relatedInformation DiagnosticRelatedInformation[]

--- @class lsp.DocumentFilter
--- @field language? string
--- @field scheme? string
--- @field pattern? string

--- @alias lsp.DocumentSelector lsp.DocumentFilter[]

--- @alias lsp.RegisterOptions any | lsp.StaticRegistrationOptions | lsp.TextDocumentRegistrationOptions

--- @class lsp.Registration
--- @field id string
--- @field method string
--- @field registerOptions? lsp.RegisterOptions

--- @alias lsp.RegistrationParams {registrations: lsp.Registration[]}

--- @class lsp.StaticRegistrationOptions
--- @field id? string

--- @class lsp.TextDocumentRegistrationOptions
--- @field documentSelector? lsp.DocumentSelector

--- @class lsp.Unregistration
--- @field id string
--- @field method string

--- @alias lsp.UnregistrationParams {unregisterations: lsp.Unregistration[]}

---@class lsp.Location
---@field uri string
---@field range lsp.Range

---@class lsp.MarkupContent
---@field kind string
---@field value string

---@class lsp.InlayHintLabelPart
---@field value string
---@field tooltip? string | lsp.MarkupContent
---@field location? lsp.Location

---@class lsp.TextEdit
---@field range lsp.Range
---@field newText string

---@class lsp.InlayHint
---@field position lsp.Position
---@field label string | lsp.InlayHintLabelPart[]
---@field kind? integer
---@field textEdits? lsp.TextEdit[]
---@field paddingLeft? boolean
---@field paddingRight? boolean
