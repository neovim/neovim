---@meta
error('Cannot require a meta file')

---@alias lsp.Handler fun(err: lsp.ResponseError?, result: any, context: lsp.HandlerContext, config?: table): ...any

---@class lsp.HandlerContext
---@field method string
---@field client_id integer
---@field bufnr? integer
---@field params? any
---@field version? integer

---@class lsp.ResponseError
---@field code integer
---@field message string
---@field data string|number|boolean|table[]|table|nil

--- @class lsp.DocumentFilter
--- @field language? string
--- @field scheme? string
--- @field pattern? string

--- @alias lsp.RegisterOptions any | lsp.StaticRegistrationOptions | lsp.TextDocumentRegistrationOptions
