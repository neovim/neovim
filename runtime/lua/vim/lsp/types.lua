---@meta

---@alias lsp-handler fun(err: lsp.ResponseError|nil, result: any, context: table, config: table|nil)

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
---@field line number
---@field character number

---@class lsp.Range
---@field start lsp.Position
---@field end lsp.Position

---@class lsp.Command
---@field title string
---@field command string
---@field arguments any|nil

---@class lsp.CodeLens
---@field range lsp.Range
---@field command lsp.Command|nil
---@field data any|nil
