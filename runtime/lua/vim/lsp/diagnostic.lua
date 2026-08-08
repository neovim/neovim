---@brief This module provides functionality for requesting LSP diagnostics for a document/workspace
---and populating them using |vim.Diagnostic|s. `DiagnosticRelatedInformation` is supported: it is
---included in the window shown by |vim.diagnostic.open_float()|. When the cursor is on a line with
---related information, |gf| jumps to the problem location.

local lsp = vim.lsp
local protocol = lsp.protocol
local util = lsp.util
local Capability = require('vim.lsp._capability')

local api = vim.api

local M = {}

---@class (private) vim.lsp.diagnostic.ClientState
---@field pull_kind 'document'|'workspace' Whether diagnostics are being updated via document or workspace pull
---@field result_id table<string, string?>  Latest responded `resultId`, keyed by `identifier`

---@class (private) Diagnostics : vim.lsp.Capability
---@field active table<integer, Diagnostics>
---@field client_state table<integer, vim.lsp.diagnostic.ClientState>
local Diagnostics = {
  name = 'diagnostics',
  method = 'textDocument/diagnostic',
  active = {},
}
Diagnostics.__index = Diagnostics
setmetatable(Diagnostics, Capability)
Capability.all[Diagnostics.name] = Diagnostics

--- Diagnostics are enabled by default
Capability.enable('diagnostics', true)

local DEFAULT_CLIENT_ID = -1

---@param severity lsp.DiagnosticSeverity
---@return vim.diagnostic.Severity
local function severity_lsp_to_vim(severity)
  if type(severity) == 'string' then
    return protocol.DiagnosticSeverity[severity] --[[@as vim.diagnostic.Severity]]
  end
  return severity
end

---@param severity vim.diagnostic.Severity|vim.diagnostic.SeverityName
---@return lsp.DiagnosticSeverity
local function severity_vim_to_lsp(severity)
  if type(severity) == 'string' then
    return vim.diagnostic.severity[severity]
  end
  return severity --[[@as lsp.DiagnosticSeverity]]
end

---@param bufnr integer
---@return string[]?
local function get_buf_lines(bufnr)
  if api.nvim_buf_is_loaded(bufnr) then
    return api.nvim_buf_get_lines(bufnr, 0, -1, false)
  end

  local filename = api.nvim_buf_get_name(bufnr)
  local f = io.open(filename)
  if not f then
    return
  end

  local content = f:read('*a')
  if not content then
    -- Some LSP servers report diagnostics at a directory level, in which case
    -- io.read() returns nil
    f:close()
    return
  end

  local lines = vim.split(content, '\n')
  f:close()
  return lines
end

--- @param diagnostic lsp.Diagnostic
--- @param client_id integer
--- @return table?
local function tags_lsp_to_vim(diagnostic, client_id)
  local tags ---@type table?
  assert(diagnostic.tags ~= vim.NIL, 'server response has invalid (null) tags')
  for _, tag in ipairs(diagnostic.tags or {}) do
    if tag == protocol.DiagnosticTag.Unnecessary then
      tags = tags or {}
      tags.unnecessary = true
    elseif tag == protocol.DiagnosticTag.Deprecated then
      tags = tags or {}
      tags.deprecated = true
    else
      lsp.log.info(string.format('Unknown DiagnosticTag %d from LSP client %d', tag, client_id))
    end
  end
  return tags
end

---@param diagnostics lsp.Diagnostic[]
---@param bufnr integer
---@param client_id integer
---@return vim.Diagnostic.Set[]
local function diagnostic_lsp_to_vim(diagnostics, bufnr, client_id)
  local buf_lines = get_buf_lines(bufnr)
  local client = lsp.get_client_by_id(client_id)
  local position_encoding = client and client.offset_encoding or 'utf-16'
  --- @param diagnostic lsp.Diagnostic
  --- @return vim.Diagnostic.Set
  return vim.tbl_map(function(diagnostic)
    local start = diagnostic.range.start
    local _end = diagnostic.range['end']
    local message = diagnostic.message
    if type(message) ~= 'string' then
      vim.notify_once(
        string.format('Unsupported Markup message from LSP client %d', client_id),
        lsp.log_levels.ERROR
      )
      --- @diagnostic disable-next-line: undefined-field,no-unknown
      message = diagnostic.message.value
    end
    local line = buf_lines and buf_lines[start.line + 1] or ''
    local end_line = line
    if _end.line > start.line then
      end_line = buf_lines and buf_lines[_end.line + 1] or ''
    end
    --- @type vim.Diagnostic.Set
    return {
      lnum = start.line,
      col = vim.str_byteindex(line, position_encoding, start.character, false),
      end_lnum = _end.line,
      end_col = vim.str_byteindex(end_line, position_encoding, _end.character, false),
      severity = severity_lsp_to_vim(diagnostic.severity),
      message = message,
      source = diagnostic.source,
      code = diagnostic.code,
      _tags = tags_lsp_to_vim(diagnostic, client_id),
      user_data = {
        lsp = diagnostic,
      },
    }
  end, diagnostics)
end

--- @param diagnostic vim.Diagnostic
--- @return lsp.DiagnosticTag[]?
local function tags_vim_to_lsp(diagnostic)
  if not diagnostic._tags then
    return
  end

  local tags = {} --- @type lsp.DiagnosticTag[]
  if diagnostic._tags.unnecessary then
    tags[#tags + 1] = protocol.DiagnosticTag.Unnecessary
  end
  if diagnostic._tags.deprecated then
    tags[#tags + 1] = protocol.DiagnosticTag.Deprecated
  end
  return tags
end

---@param identifier string?
---@return string
local function result_id_key(identifier)
  return identifier or 'nil'
end

--- Converts the input `vim.Diagnostic`s to LSP diagnostics.
--- @param diagnostics vim.Diagnostic[]
--- @return lsp.Diagnostic[]
function M.from(diagnostics)
  ---@param diagnostic vim.Diagnostic
  ---@return lsp.Diagnostic
  return vim.tbl_map(function(diagnostic)
    local user_data = diagnostic.user_data or {}
    if user_data.lsp then
      return user_data.lsp
    end
    return {
      range = {
        start = {
          line = diagnostic.lnum,
          character = diagnostic.col,
        },
        ['end'] = {
          line = diagnostic.end_lnum,
          character = diagnostic.end_col,
        },
      },
      severity = severity_vim_to_lsp(diagnostic.severity),
      message = diagnostic.message,
      source = diagnostic.source,
      code = diagnostic.code,
      tags = tags_vim_to_lsp(diagnostic),
    }
  end, diagnostics)
end

---@type table<integer, integer>
local client_push_namespaces = {}

---@type table<string, integer>
local client_pull_namespaces = {}

--- Get the diagnostic namespace associated with an LSP client |vim.diagnostic| for diagnostics
---
---@param client_id integer The id of the LSP client
---@param is_pull boolean? Whether the namespace is for a pull or push client. Defaults to
---                        `false` (push).
---@param pull_id string? (default: nil) Optional identifier for pull diagnostic providers.
---                       Only used if `is_pull` is `true`.
function M.get_namespace(client_id, is_pull, pull_id)
  vim.validate('client_id', client_id, 'number')
  vim.validate('is_pull', is_pull, 'boolean', true)
  vim.validate('pull_id', pull_id, 'string', true)

  local client = lsp.get_client_by_id(client_id)
  if is_pull then
    pull_id = pull_id or 'nil'
    local key = ('%d:%s'):format(client_id, pull_id)
    local name = ('nvim.lsp.%s.%d.%s'):format(
      client and client.name or 'unknown',
      client_id,
      pull_id
    )
    local ns = client_pull_namespaces[key]
    if not ns then
      ns = api.nvim_create_namespace(name)
      client_pull_namespaces[key] = ns
    end
    return ns
  end

  local ns = client_push_namespaces[client_id]
  if not ns then
    local name = ('nvim.lsp.%s.%d'):format(client and client.name or 'unknown', client_id)
    ns = api.nvim_create_namespace(name)
    client_push_namespaces[client_id] = ns
  end
  return ns
end

--- @param uri string
--- @param client_id? integer
--- @param diagnostics lsp.Diagnostic[]
--- @param is_pull? boolean
--- @param pull_id? string
local function handle_diagnostics(uri, client_id, diagnostics, is_pull, pull_id)
  local fname = vim.uri_to_fname(uri)

  if #diagnostics == 0 and vim.fn.bufexists(fname) == 0 then
    return
  end

  local bufnr = vim.fn.bufadd(fname)
  if not bufnr then
    return
  end

  client_id = client_id or DEFAULT_CLIENT_ID

  local namespace = M.get_namespace(client_id, is_pull, pull_id)

  vim.diagnostic.set(namespace, bufnr, diagnostic_lsp_to_vim(diagnostics, bufnr, client_id))
end

--- |lsp-handler| for the method "textDocument/publishDiagnostics"
---
--- See |vim.diagnostic.config()| for configuration options. Handler-specific
--- configuration can be set using |vim.func.on_fun()|:
---     <pre>lua
---     vim.func.on_fun(vim.lsp.handlers, 'textDocument/publishDiagnostics', function(fn, args)
---       -- Enable underline, use default values
---       args.config.underline = true
---       -- Enable virtual text, override spacing to 4
---       args.config.virtual_text = { spacing = 4 }
---       -- Dynamically turn signs on/off via buffer-local variables.
---       args.config.signs = function(namespace, bufnr)
---         return vim.b[bufnr].show_signs == true
---       end
---       -- Disable a feature.
---       args.config.update_in_insert = false
---       return vim.lsp.diagnostic.on_publish_diagnostics(unpack(args))
---     end)
---     </pre>
---
---@param config table Configuration table (see |vim.diagnostic.config()|).
---
---@param _ lsp.ResponseError?
---@param params lsp.PublishDiagnosticsParams
---@param ctx lsp.HandlerContext
function M.on_publish_diagnostics(_, params, ctx)
  -- TODO(tris203): if empty array then clear diags
  -- https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocument_publishDiagnostics
  handle_diagnostics(params.uri, ctx.client_id, params.diagnostics)
end

--- |lsp-handler| for the method "textDocument/diagnostic"
---
--- See |vim.diagnostic.config()| for configuration options.
---
---@param error lsp.ResponseError?
---@param result lsp.DocumentDiagnosticReport
---@param ctx lsp.HandlerContext
function M.on_diagnostic(error, result, ctx)
  local client_id = ctx.client_id
  local bufnr = assert(ctx.bufnr)
  local state = Diagnostics.active[bufnr] and Diagnostics.active[bufnr].client_state[client_id]
  if not state then
    return
  end

  if error ~= nil then
    if error.code == protocol.ErrorCodes.ServerCancelled then
      if error.data == nil or error.data.retriggerRequest ~= false then
        local client = assert(lsp.get_client_by_id(ctx.client_id))
        ---@diagnostic disable-next-line: param-type-mismatch
        client:request(ctx.method, ctx.params, nil, ctx.bufnr)
      end
    else
      vim.lsp.log.error('diagnostics', error)
    end
    return
  end

  if result == nil then
    return
  end

  ---@type lsp.DocumentDiagnosticParams
  local params = ctx.params
  local key = result_id_key(params.identifier)
  state.result_id[key] = result.resultId

  if result.kind == 'unchanged' then
    return
  end

  handle_diagnostics(params.textDocument.uri, client_id, result.items, true, params.identifier)

  for uri, related_result in pairs(result.relatedDocuments or {}) do
    if related_result.kind == 'full' then
      handle_diagnostics(uri, client_id, related_result.items, true, params.identifier)
    end

    -- Create a new client state if it doesn't exist for the related document. This will not enable
    -- diagnostic pulling by itself, but will allow previous result IDs to be passed correctly the
    -- next time this buffer's diagnostics are pulled.
    local related_bufnr = vim.uri_to_bufnr(uri)
    local related_diagnostics = Diagnostics.active[related_bufnr] or Diagnostics:new(related_bufnr)
    local related_state = related_diagnostics.client_state[client_id]
    if not related_state then
      related_state = { pull_kind = 'document', result_id = {} }
      related_diagnostics.client_state[client_id] = related_state
    end
    related_state.result_id[key] = related_result.resultId
  end
end

--- Clear diagnostics from pull based clients
---@package
---@param client_id integer?
function Diagnostics:clear(client_id)
  for key, namespace in pairs(client_pull_namespaces) do
    if not client_id or vim.startswith(key, ('%d:'):format(client_id)) then
      vim.diagnostic.reset(namespace, self.bufnr)
    end
  end
end

--- Refresh diagnostics, only if we have attached clients that support it
---@package
---@param client_id integer Client ID to refresh
function Diagnostics:refresh(client_id)
  local client = vim.lsp.get_client_by_id(client_id)

  local method = 'textDocument/diagnostic'
  local clients = { client }

  util._cancel_requests({
    bufnr = self.bufnr,
    clients = clients,
    method = method,
    type = 'pending',
  })

  local state = self.client_state[client_id]
  if client and state then
    ---@param cap lsp.DiagnosticRegistrationOptions
    client:_provider_foreach(method, function(cap)
      local key = result_id_key(cap.identifier)
      ---@type lsp.DocumentDiagnosticParams
      local params = {
        identifier = cap.identifier,
        textDocument = util.make_text_document_params(self.bufnr),
        previousResultId = state.result_id[key],
      }
      client:request(method, params, nil, self.bufnr)
    end)
  end
end

--- |lsp-handler| for the method `workspace/diagnostic/refresh`
---@param ctx lsp.HandlerContext
---@private
function M.on_refresh(err, _, ctx)
  if err then
    return vim.NIL
  end
  local client = vim.lsp.get_client_by_id(ctx.client_id)
  if client == nil then
    return vim.NIL
  end
  if client:supports_method('workspace/diagnostic') then
    M._workspace_diagnostics({ client_id = ctx.client_id })
  end

  -- Always refresh document-pull buffers. Workspace diagnostics only cover
  -- buffers with pull_kind == 'workspace', so open buffers must be refreshed
  -- individually or their diagnostics go stale until the next didChange.
  for bufnr in pairs(client.attached_buffers or {}) do
    local provider = Diagnostics.active[bufnr]
    local state = provider and provider.client_state[ctx.client_id]
    if state and state.pull_kind == 'document' then
      provider:refresh(ctx.client_id)
    end
  end

  return vim.NIL
end

--- Enable pull diagnostics for a buffer from a client
---@package
function Diagnostics:on_attach(client_id)
  local state = self.client_state[client_id]

  if state then
    state.pull_kind = 'document'
  else
    state = { pull_kind = 'document', result_id = {} }
    self.client_state[client_id] = state
  end

  self:refresh(client_id)
end

--- Disable pull diagnostics for a buffer from a client
---@package
function Diagnostics:on_detach(client_id)
  local state = self.client_state[client_id]
  if state then
    self:clear(client_id)
    self.client_state[client_id] = nil
  end
end

---@private
function Diagnostics:on_close(client_id)
  local state = self.client_state[client_id]
  if state and state.pull_kind == 'document' then
    self:clear(client_id)
  end
end

---@private
function Diagnostics:on_change(client_id)
  local state = self.client_state[client_id]
  if state and state.pull_kind == 'document' then
    self:refresh(client_id)
  end
end

--- Returns the result IDs from the reports provided by the given client.
--- @return lsp.PreviousResultId[]
--- @param client_id integer
--- @param identifier string?
local function previous_result_ids(client_id, identifier)
  local results = {} ---@type lsp.PreviousResultId[]
  local key = result_id_key(identifier)

  for bufnr, provider in pairs(Diagnostics.active) do
    local state = provider.client_state[client_id]
    if state then
      local result_id = state.result_id[key]
      if result_id then
        results[#results + 1] = {
          uri = vim.uri_from_bufnr(bufnr),
          value = result_id,
        }
      end
    end
  end

  return results
end

--- Request workspace-wide diagnostics.
--- @param opts vim.lsp.WorkspaceDiagnosticsOpts
function M._workspace_diagnostics(opts)
  local clients = lsp.get_clients({ method = 'workspace/diagnostic', id = opts.client_id })

  --- @param error lsp.ResponseError?
  --- @param result lsp.WorkspaceDiagnosticReport
  --- @param ctx lsp.HandlerContext
  local function handler(error, result, ctx)
    -- Check for retrigger requests on cancellation errors.
    -- Unless `retriggerRequest` is explicitly disabled, try again.
    if error ~= nil and error.code == protocol.ErrorCodes.ServerCancelled then
      if error.data == nil or error.data.retriggerRequest ~= false then
        local client = assert(lsp.get_client_by_id(ctx.client_id))
        client:request('workspace/diagnostic', ctx.params, handler)
      end
      return
    end

    if error == nil and result ~= nil then
      ---@type lsp.WorkspaceDiagnosticParams
      local params = ctx.params
      for _, report in ipairs(result.items) do
        local bufnr = vim.uri_to_bufnr(report.uri)

        -- Start tracking the buffer (but don't send "textDocument/diagnostic" requests for it).
        local provider = Diagnostics.active[bufnr] or Diagnostics:new(bufnr)
        local state = provider.client_state[ctx.client_id]
        if not state then
          state = { pull_kind = 'workspace', result_id = {} }
          provider.client_state[ctx.client_id] = state
        end

        -- We favor document pull requests over workspace results, so only update the buffer
        -- state if we're not pulling document diagnostics for this buffer.
        if state.pull_kind == 'workspace' and report.kind == 'full' then
          handle_diagnostics(report.uri, ctx.client_id, report.items, true, params.identifier)
          local key = result_id_key(params.identifier)
          state.result_id[key] = report.resultId
        end
      end
    end
  end

  for _, client in ipairs(clients) do
    ---@param cap lsp.DiagnosticRegistrationOptions
    client:_provider_foreach('workspace/diagnostic', function(cap)
      --- @type lsp.WorkspaceDiagnosticParams
      local params = {
        identifier = cap.identifier,
        previousResultIds = previous_result_ids(client.id, cap.identifier),
      }

      client:request('workspace/diagnostic', params, handler)
    end)
  end
end

return M
