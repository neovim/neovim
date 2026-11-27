---@meta
error('Cannot require a meta file')

---@alias lsp.Handler fun(err: vim.json.rpc.Error?, result: any, context: lsp.HandlerContext, config?: table): ...any
---@alias lsp.MultiHandler fun(results: table<integer,{err: vim.json.rpc.Error?, result: any, context: lsp.HandlerContext}>, context: lsp.HandlerContext, config?: table): ...any

---@class lsp.HandlerContext
---@field method string
---@field client_id integer
---@field request_id? integer
---@field bufnr? integer
---@field params? any
---@field version? integer
