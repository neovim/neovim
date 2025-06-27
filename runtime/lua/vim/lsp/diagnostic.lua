local lsp = vim.lsp
local protocol = lsp.protocol
local ms = protocol.Methods
local util = lsp.util

local api = vim.api

local M = {}

local augroup = api.nvim_create_augroup('nvim.lsp.diagnostic', {})

---@class (private) vim.lsp.diagnostic.BufState
---@field pull_kind 'document'|'workspace'|'disabled' Whether diagnostics are being updated via document pull, workspace pull, or disabled.
---@field client_result_id table<integer, string?> Latest responded `resultId`

---@type table<integer, vim.lsp.diagnostic.BufState>
local bufstates = {}

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
---@param is_pull boolean? Whether the namespace is for a pull or push client. Defaults to push
function M.get_namespace(client_id, is_pull)
  vim.validate('client_id', client_id, 'number')

  local client = lsp.get_client_by_id(client_id)
  if is_pull then
    local server_id =
      vim.tbl_get((client or {}).server_capabilities or {}, 'diagnosticProvider', 'identifier')
    local key = ('%d:%s'):format(client_id, server_id or 'nil')
    local name = ('nvim.lsp.%s.%d.%s'):format(
      client and client.name or 'unknown',
      client_id,
      server_id or 'nil'
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
--- @param is_pull boolean
local function handle_diagnostics(uri, client_id, diagnostics, is_pull)
  local fname = vim.uri_to_fname(uri)

  if #diagnostics == 0 and vim.fn.bufexists(fname) == 0 then
    return
  end

  local bufnr = vim.fn.bufadd(fname)
  if not bufnr then
    return
  end

  client_id = client_id or DEFAULT_CLIENT_ID

  local namespace = M.get_namespace(client_id, is_pull)

  vim.diagnostic.set(namespace, bufnr, diagnostic_lsp_to_vim(diagnostics, bufnr, client_id))
end

--- |lsp-handler| for the method "textDocument/publishDiagnostics"
---
--- See |vim.diagnostic.config()| for configuration options.
---
---@param _ lsp.ResponseError?
---@param params lsp.PublishDiagnosticsParams
---@param ctx lsp.HandlerContext
function M.on_publish_diagnostics(_, params, ctx)
  handle_diagnostics(params.uri, ctx.client_id, params.diagnostics, false)
end

--- |lsp-handler| for the method "textDocument/diagnostic"
---
--- See |vim.diagnostic.config()| for configuration options.
---
---@param error lsp.ResponseError?
---@param result lsp.DocumentDiagnosticReport
---@param ctx lsp.HandlerContext
function M.on_diagnostic(error, result, ctx)
  if error ~= nil and error.code == protocol.ErrorCodes.ServerCancelled then
    if error.data == nil or error.data.retriggerRequest ~= false then
      local client = assert(lsp.get_client_by_id(ctx.client_id))
      client:request(ctx.method, ctx.params)
    end
    return
  end

  if result == nil or result.kind == 'unchanged' then
    return
  end

  local client_id = ctx.client_id
  handle_diagnostics(ctx.params.textDocument.uri, client_id, result.items, true)

  local bufnr = assert(ctx.bufnr)
  local bufstate = bufstates[bufnr]
  bufstate.client_result_id[client_id] = result.resultId
end

--- Clear push diagnostics and diagnostic cache.
---
--- Diagnostic producers should prefer |vim.diagnostic.reset()|. However,
--- this method signature is still used internally in some parts of the LSP
--- implementation so it's simply marked @private rather than @deprecated.
---
---@param client_id integer
---@param buffer_client_map table<integer, table<integer, table>> map of buffers to active clients
---@private
function M.reset(client_id, buffer_client_map)
  buffer_client_map = vim.deepcopy(buffer_client_map)
  vim.schedule(function()
    for bufnr, client_ids in pairs(buffer_client_map) do
      if client_ids[client_id] then
        local namespace = M.get_namespace(client_id, false)
        vim.diagnostic.reset(namespace, bufnr)
      end
    end
  end)
end

--- Get the diagnostics by line
---
--- Marked private as this is used internally by the LSP subsystem, but
--- most users should instead prefer |vim.diagnostic.get()|.
---
---@param bufnr integer|nil The buffer number
---@param line_nr integer|nil The line number
---@param opts {severity?:lsp.DiagnosticSeverity}?
---         - severity: (lsp.DiagnosticSeverity)
---             - Only return diagnostics with this severity.
---@param client_id integer|nil the client id
---@return table Table with map of line number to list of diagnostics.
---              Structured: { [1] = {...}, [5] = {.... } }
---@private
function M.get_line_diagnostics(bufnr, line_nr, opts, client_id)
  vim.deprecate('vim.lsp.diagnostic.get_line_diagnostics', 'vim.diagnostic.get', '0.12')
  local diag_opts = {} --- @type vim.diagnostic.GetOpts

  if opts and opts.severity then
    diag_opts.severity = severity_lsp_to_vim(opts.severity)
  end

  if client_id then
    diag_opts.namespace = M.get_namespace(client_id, false)
  end

  diag_opts.lnum = line_nr or (api.nvim_win_get_cursor(0)[1] - 1)

  return M.from(vim.diagnostic.get(bufnr, diag_opts))
end

--- Clear diagnostics from pull based clients
local function clear(bufnr)
  for _, namespace in pairs(client_pull_namespaces) do
    vim.diagnostic.reset(namespace, bufnr)
  end
end

--- Disable pull diagnostics for a buffer
--- @param bufnr integer
local function disable(bufnr)
  local bufstate = bufstates[bufnr]
  if bufstate then
    bufstate.pull_kind = 'disabled'
  end
  clear(bufnr)
end

--- Refresh diagnostics, only if we have attached clients that support it
---@param bufnr integer buffer number
---@param client_id? integer Client ID to refresh (default: all clients)
---@param only_visible? boolean Whether to only refresh for the visible regions of the buffer (default: false)
local function refresh(bufnr, client_id, only_visible)
  if
    only_visible
    and vim.iter(api.nvim_list_wins()):all(function(window)
      return api.nvim_win_get_buf(window) ~= bufnr
    end)
  then
    return
  end

  local method = ms.textDocument_diagnostic
  local clients = lsp.get_clients({ bufnr = bufnr, method = method, id = client_id })
  local bufstate = bufstates[bufnr]

  util._cancel_requests({
    bufnr = bufnr,
    clients = clients,
    method = method,
    type = 'pending',
  })
  for _, client in ipairs(clients) do
    ---@type lsp.DocumentDiagnosticParams
    local params = {
      textDocument = util.make_text_document_params(bufnr),
      previousResultId = bufstate.client_result_id[client.id],
    }
    client:request(method, params, nil, bufnr)
  end
end

--- Enable pull diagnostics for a buffer
---@param bufnr (integer) Buffer handle, or 0 for current
function M._enable(bufnr)
  bufnr = vim._resolve_bufnr(bufnr)

  if bufstates[bufnr] then
    -- If we're already pulling diagnostics for this buffer, nothing to do here.
    if bufstates[bufnr].pull_kind == 'document' then
      return
    end
    -- Else diagnostics were disabled or we were using workspace diagnostics.
    bufstates[bufnr].pull_kind = 'document'
  else
    bufstates[bufnr] = { pull_kind = 'document', client_result_id = {} }
  end

  api.nvim_create_autocmd('LspNotify', {
    buffer = bufnr,
    callback = function(opts)
      if
        opts.data.method ~= ms.textDocument_didChange
        and opts.data.method ~= ms.textDocument_didOpen
      then
        return
      end
      if bufstates[bufnr] and bufstates[bufnr].pull_kind == 'document' then
        local client_id = opts.data.client_id --- @type integer?
        refresh(bufnr, client_id, true)
      end
    end,
    group = augroup,
  })

  api.nvim_buf_attach(bufnr, false, {
    on_reload = function()
      if bufstates[bufnr] and bufstates[bufnr].pull_kind == 'document' then
        refresh(bufnr)
      end
    end,
    on_detach = function()
      disable(bufnr)
    end,
  })

  api.nvim_create_autocmd('LspDetach', {
    buffer = bufnr,
    callback = function(args)
      local clients = lsp.get_clients({ bufnr = bufnr, method = ms.textDocument_diagnostic })

      if
        not vim.iter(clients):any(function(c)
          return c.id ~= args.data.client_id
        end)
      then
        disable(bufnr)
      end
    end,
    group = augroup,
  })
end

--- Returns the result IDs from the reports provided by the given client.
--- @return lsp.PreviousResultId[]
local function previous_result_ids(client_id)
  local results = {} ---@type lsp.PreviousResultId[]

  for bufnr, state in pairs(bufstates) do
    if state.pull_kind ~= 'disabled' then
      for buf_client_id, result_id in pairs(state.client_result_id) do
        if buf_client_id == client_id then
          results[#results + 1] = {
            uri = vim.uri_from_bufnr(bufnr),
            value = result_id,
          }
          break
        end
      end
    end
  end

  return results
end

--- Request workspace-wide diagnostics.
--- @param opts vim.lsp.WorkspaceDiagnosticsOpts
function M._workspace_diagnostics(opts)
  local clients = lsp.get_clients({ method = ms.workspace_diagnostic, id = opts.client_id })

  --- @param error lsp.ResponseError?
  --- @param result lsp.WorkspaceDiagnosticReport
  --- @param ctx lsp.HandlerContext
  local function handler(error, result, ctx)
    -- Check for retrigger requests on cancellation errors.
    -- Unless `retriggerRequest` is explicitly disabled, try again.
    if error ~= nil and error.code == lsp.protocol.ErrorCodes.ServerCancelled then
      if error.data == nil or error.data.retriggerRequest ~= false then
        local client = assert(lsp.get_client_by_id(ctx.client_id))
        client:request(ms.workspace_diagnostic, ctx.params, handler)
      end
      return
    end

    if error == nil and result ~= nil then
      for _, report in ipairs(result.items) do
        local bufnr = vim.uri_to_bufnr(report.uri)

        -- Start tracking the buffer (but don't send "textDocument/diagnostic" requests for it).
        if not bufstates[bufnr] then
          bufstates[bufnr] = { pull_kind = 'workspace', client_result_id = {} }
        end

        -- We favor document pull requests over workspace results, so only update the buffer
        -- state if we're not pulling document diagnostics for this buffer.
        if bufstates[bufnr].pull_kind == 'workspace' and report.kind == 'full' then
          handle_diagnostics(report.uri, ctx.client_id, report.items, true)
          bufstates[bufnr].client_result_id[ctx.client_id] = report.resultId
        end
      end
    end
  end

  for _, client in ipairs(clients) do
    --- @type lsp.WorkspaceDiagnosticParams
    local params = {
      identifier = vim.tbl_get(client, 'server_capabilities, diagnosticProvider', 'identifier'),
      previousResultIds = previous_result_ids(client.id),
    }

    client:request(ms.workspace_diagnostic, params, handler)
  end
end

return M
