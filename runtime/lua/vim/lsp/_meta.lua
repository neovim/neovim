---@meta
error('Cannot require a meta file')

-- TODO: Consider moving this to vim/lsp/handlers.lua; or stay here?

---LSP Handlers on the Nvim side, see |lsp-handler| for documentation.
---See also |lsp-handler-resolution|
---@alias vim.lsp.Handler vim.lsp.ResponseHandler | vim.lsp.RequestHandler | vim.lsp.NotificationHandler
---
---Handles a response from the server, see |lsp-response|
---@alias vim.lsp.ResponseHandler fun(err: lsp.ResponseError?, result: any, context: lsp.HandlerContext, config?: table)
---
---Handles a request made from the server, see |lsp-request| and |lsp-handler|.
---Returns either an `result` object or a `ResponseError` object to send back to LSP. see |lsp-handler-return|
---@alias vim.lsp.RequestHandler fun(err: lsp.ResponseError?, params: any, context: lsp.HandlerContext, config?: table): lsp.LSPAny?, lsp.ResponseError?
---
---Handles a notification sent from the server, see |lsp-notification|
---@alias vim.lsp.NotificationHandler fun(err: lsp.ResponseError?, params: any, context: lsp.HandlerContext, config?: table)

---@class lsp.HandlerContext
---@field method string
---@field client_id integer
---@field bufnr? integer
---@field params? any
---@field version? integer

-- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#responseMessage
---@class lsp.ResponseError
---@field code integer see `lsp.ErrorCodes` and `lsp.LSPErrorCodes`.
---@field message string
---@field data string|number|boolean|table[]|table|nil
