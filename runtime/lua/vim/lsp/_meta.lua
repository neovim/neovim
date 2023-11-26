---@meta
error('Cannot require a meta file')

---@alias lsp-handler fun(err: lsp.ResponseError|nil, result: any, context: lsp.HandlerContext, config: table|nil): any?

---@class lsp.HandlerContext
---@field method string
---@field client_id integer
---@field bufnr? integer
---@field params? any

---@class lsp.ResponseError
---@field code integer
---@field message string
---@field data string|number|boolean|table[]|table|nil

--- @class lsp.DocumentFilter
--- @field language? string
--- @field scheme? string
--- @field pattern? string

--- @alias lsp.RegisterOptions any | lsp.StaticRegistrationOptions | lsp.TextDocumentRegistrationOptions
