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
