local log = require 'vim.lsp.log'
local protocol = require 'vim.lsp.protocol'
local util = require 'vim.lsp.util'
local api = vim.api

local M = {}

M['textDocument/publishDiagnostics'] = function(_, _, result)
  if not result then return end
  local uri = result.uri
  local bufnr = vim.uri_to_bufnr(uri)
  if not bufnr then
    api.nvim_err_writeln(string.format("LSP.publishDiagnostics: Couldn't find buffer for %s", uri))
    return
  end
  util.buf_clear_diagnostics(bufnr)
  util.buf_diagnostics_save_positions(bufnr, result.diagnostics)
  util.buf_diagnostics_underline(bufnr, result.diagnostics)
  util.buf_diagnostics_virtual_text(bufnr, result.diagnostics)
  -- util.buf_loclist(bufnr, result.diagnostics)
end

local function log_message(_, _, result, client_id)
  local message_type = result.type
  local message = result.message
  local client = vim.lsp.get_client_by_id(client_id)
  local client_name = client and client.name or string.format("id=%d", client_id)
  if not client then
    api.nvim_err_writeln(string.format("LSP[%s] client has shut down after sending the message", client_name))
  end
  if message_type == protocol.MessageType.Error then
    -- Might want to not use err_writeln,
    -- but displaying a message with red highlights or something
    api.nvim_err_writeln(string.format("LSP[%s] %s", client_name, message))
  else
    local message_type_name = protocol.MessageType[message_type]
    api.nvim_out_write(string.format("LSP[%s][%s] %s\n", client_name, message_type_name, message))
  end
  return result
end

M['window/showMessage'] = log_message
M['window/logMessage'] = log_message

-- Add boilerplate error validation and logging for all of these.
for k, fn in pairs(M) do
  M[k] = function(err, method, params, client_id)
    local _ = log.debug() and log.debug('default_callback', method, { params = params, client_id = client_id, err = err })
    if err then
      error(tostring(err))
    end
    return fn(err, method, params, client_id)
  end
end

return M
-- vim:sw=2 ts=2 et
