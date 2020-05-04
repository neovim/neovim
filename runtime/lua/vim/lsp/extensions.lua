local vim = vim
local validate = vim.validate
local log = require 'vim.lsp.log'
local util = require 'vim.lsp.util'
local buf = require 'vim.lsp.buf'

local M = {}

-- callback to preview a location in a floating window instead
-- of jumping to it
local function preview_location_callback(_, method, result)
  if result == nil or vim.tbl_isempty(result) then
    log.info(method, 'No location found')
    return nil
  end
  if vim.tbl_islist(result) then
    util.preview_location(result[1])
  else
    util.preview_location(result)
  end
end

local function peek_request(method, params)
  validate {
    method = {method, 's'};
  }
  return vim.lsp.buf_request(0, method, params, preview_location_callback)
end

function M.peek_definition()
  local params = util.make_position_params()
  peek_request('textDocument/definition', params)
end
function M.peek_declaration()
  local params = util.make_position_params()
  peek_request('textDocument/declaration', params)
end
function M.peek_implementation()
  local params = util.make_position_params()
  peek_request('textDocument/implementation', params)
end
function M.peek_typeDefinition()
  local params = util.make_position_params()
  peek_request('textDocument/typeDefinition', params)
end

return M
-- vim:sw=2 ts=2 et
