---@meta
error('Cannot require a meta file')

---@alias lsp.Handler fun(err: lsp.ResponseError?, result: any, context: lsp.HandlerContext, config?: table): ...any
---@alias lsp.MultiHandler fun(results: table<integer,{err: lsp.ResponseError?, result: any, context: lsp.HandlerContext}>, context: lsp.HandlerContext, config?: table): ...any

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
