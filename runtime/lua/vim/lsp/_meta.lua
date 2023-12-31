---@meta
error('Cannot require a meta file')

-- TODO: Consider moving this to vim/lsp/handlers.lua; or stay here?

---LSP Handlers, see |lsp-handler| for documentation. see also |lsp-handler-resolution|
---@alias vim.lsp.Handler vim.lsp.ResponseHandler | vim.lsp.RequestHandler | vim.lsp.NotificationHandler
---
---Handles response sent from the server, see |lsp-response|
---@alias vim.lsp.ResponseHandler fun(err: lsp.ResponseError?, result: any, context: lsp.HandlerContext, config?: table)
---
---Handles request sent from the server, see |lsp-request|
---@alias vim.lsp.RequestHandler fun(err: lsp.ResponseError?, params: any, context: lsp.HandlerContext, config?: table): ...any
---
---Handles notification sent from the server, see |lsp-notification|
---@alias vim.lsp.NotificationHandler fun(err: lsp.ResponseError?, params: any, context: lsp.HandlerContext, config?: table): vim.NIL|nil

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
