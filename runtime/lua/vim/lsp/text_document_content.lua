--- @brief
--- This module provides the LSP `workspace/textDocumentContent` feature, for loading virtual
--- documents whose content is provided by an attached language server.
---
--- LSP spec: https://microsoft.github.io/language-server-protocol/specifications/lsp/3.18/specification/#workspace_textDocumentContent

local api = vim.api
local log = require('vim.lsp.log')

local Capability = require('vim.lsp._capability')

local M = {}

---@class (private) vim.lsp.text_document_content.Provider : vim.lsp.Capability
---@field active table<integer, vim.lsp.text_document_content.Provider?>
---@field client_state table<integer, table>
local Provider = {
  name = 'text_document_content',
  method = 'workspace/textDocumentContent',
  active = {},
}
Provider.__index = Provider
setmetatable(Provider, Capability)
Capability.all[Provider.name] = Provider

local augroup = api.nvim_create_augroup('nvim.lsp.text_document_content', {})
local active_patterns = {} --- @type string[]

---@param client vim.lsp.Client
---@return string[]
local function client_schemes(client)
  local schemes = {} --- @type string[]
  ---@param cap lsp.TextDocumentContentRegistrationOptions
  client:_provider_foreach('workspace/textDocumentContent', function(cap)
    for _, scheme in ipairs(cap.schemes or {}) do
      schemes[#schemes + 1] = scheme
    end
  end)
  return schemes
end

---@param client vim.lsp.Client
---@param uri string
---@return boolean
local function client_supports_uri(client, uri)
  return client:supports_method('workspace/textDocumentContent')
    and vim.iter(client_schemes(client)):any(function(scheme)
      return vim.startswith(uri, scheme .. ':')
    end)
end

---@return table<string, true>
local function supported_schemes()
  local schemes = {} --- @type table<string, true>
  for _, client in ipairs(vim.lsp.get_clients()) do
    if client:supports_method('workspace/textDocumentContent') then
      vim.iter(client_schemes(client)):each(function(scheme)
        schemes[scheme] = true
      end)
    end
  end
  return schemes
end

---@param text string
---@return string[]
local function text_to_lines(text)
  text = text:gsub('\r\n?', '\n')
  local lines = vim.split(text, '\n', { plain = true })
  if #text > 0 and text:sub(-1) == '\n' then
    table.remove(lines, #lines)
  end
  return lines
end

---@param bufnr integer
local function set_virtual_buf_options(bufnr)
  vim.bo[bufnr].buftype = 'nofile'
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].readonly = true
  vim.bo[bufnr].modifiable = false
end

---@param bufnr integer
---@param text string
local function apply_content(bufnr, text)
  if not api.nvim_buf_is_valid(bufnr) then
    return
  end

  vim.bo[bufnr].modifiable = true
  api.nvim_buf_set_lines(bufnr, 0, -1, false, text_to_lines(text))
  vim.bo[bufnr].modified = false
  set_virtual_buf_options(bufnr)
end

---@param uri string
---@param bufnr integer
---@return vim.lsp.Client?
local function select_client(uri, bufnr)
  local clients = {} --- @type vim.lsp.Client[]
  local candidates = vim.lsp.get_clients({
    bufnr = bufnr,
    method = 'workspace/textDocumentContent',
  }) or {}
  if #candidates == 0 then
    candidates = vim.lsp.get_clients({ method = 'workspace/textDocumentContent' })
  end

  for _, client in ipairs(candidates) do
    if client_supports_uri(client, uri) then
      clients[#clients + 1] = client
    end
  end
  table.sort(clients, function(a, b)
    return a.id < b.id
  end)

  if #clients > 1 then
    local client = clients[1]
    vim.notify(
      ('Multiple LSP clients support workspace/textDocumentContent for %s; using %s (id=%d)'):format(
        uri,
        client.name,
        client.id
      ),
      vim.log.levels.WARN
    )
  end

  return clients[1]
end

---@param client vim.lsp.Client
---@param bufnr integer
---@param uri string
---@param notify_error boolean
local function request_content(client, bufnr, uri, notify_error)
  ---@param message string
  local function notify(message)
    if notify_error then
      vim.notify(
        ('Failed to load LSP text document content for %s: %s'):format(uri, message),
        vim.log.levels.ERROR
      )
    end
  end

  local response, err =
    client:request_sync('workspace/textDocumentContent', { uri = uri }, nil, bufnr)
  if err then
    notify(err)
    log.error('text_document_content', err)
    return
  end

  if not response then
    return
  end

  if response.err then
    notify(response.err.message)
    log.error('text_document_content', response.err)
    return
  end

  apply_content(bufnr, response.result and response.result.text or '')
end

local function on_buf_read(ev)
  set_virtual_buf_options(ev.buf)

  local client = select_client(ev.file, ev.buf)
  if not client then
    vim.notify(
      ('No LSP client supports workspace/textDocumentContent for %s'):format(ev.file),
      vim.log.levels.ERROR
    )
    return
  end

  request_content(client, ev.buf, ev.file, true)
end

--- Rebuild the global `BufReadCmd` autocmds from all active text document content providers.
function M._update_autocmds()
  local patterns = vim.tbl_keys(supported_schemes())
  table.sort(patterns)
  patterns = vim
    .iter(patterns)
    :map(function(scheme)
      return { scheme .. ':*', scheme .. '://*' }
    end)
    :flatten()
    :totable()

  if vim.deep_equal(patterns, active_patterns) then
    return
  end

  active_patterns = patterns
  api.nvim_clear_autocmds({ group = augroup })
  if #patterns > 0 then
    api.nvim_create_autocmd('BufReadCmd', {
      group = augroup,
      pattern = patterns,
      desc = 'Load LSP text document content',
      callback = on_buf_read,
    })
  end
end

---@package
---@param bufnr integer
---@return vim.lsp.text_document_content.Provider
function Provider:new(bufnr)
  self = Capability.new(self, bufnr)
  self.client_state = {}
  return self
end

---@package
---@param client_id integer
function Provider:on_attach(client_id)
  self.client_state[client_id] = {}
  M._update_autocmds()
  vim.schedule(M._update_autocmds)
end

---@package
---@param client_id integer
function Provider:on_detach(client_id)
  self.client_state[client_id] = nil
  M._update_autocmds()
  vim.schedule(M._update_autocmds)
end

---@package
function Provider:destroy()
  Capability.destroy(self)
  M._update_autocmds()
end

--- |lsp-handler| for the method `workspace/textDocumentContent/refresh`
---
---@private
---@type lsp.Handler
---@param params? lsp.TextDocumentContentRefreshParams
---@param ctx lsp.HandlerContext
function M.on_refresh(err, params, ctx)
  if err then
    return vim.NIL
  end

  if not (params and params.uri) then
    return vim.NIL
  end

  local client = vim.lsp.get_client_by_id(ctx.client_id)
  if client == nil then
    return vim.NIL
  end

  local bufnr = vim.uri_to_bufnr(params.uri)
  if not api.nvim_buf_is_loaded(bufnr) then
    return vim.NIL
  end

  if client_supports_uri(client, params.uri) then
    request_content(client, bufnr, params.uri, false)
  end

  return vim.NIL
end

Capability.enable('text_document_content', true)

return M
