local protocol = require('vim.lsp.protocol')
local ms = protocol.Methods

local api = vim.api

local M = {}

local augroup = api.nvim_create_augroup('nvim.lsp.diagnostic', {})

local DEFAULT_CLIENT_ID = -1

---@param severity lsp.DiagnosticSeverity
local function severity_lsp_to_vim(severity)
  if type(severity) == 'string' then
    severity = protocol.DiagnosticSeverity[severity] --- @type integer
  end
  return severity
end

---@return lsp.DiagnosticSeverity
local function severity_vim_to_lsp(severity)
  if type(severity) == 'string' then
    severity = vim.diagnostic.severity[severity] --- @type integer
  end
  return severity
end

---@param bufnr integer
---@return string[]?
local function get_buf_lines(bufnr)
  if vim.api.nvim_buf_is_loaded(bufnr) then
    return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  end

  local filename = vim.api.nvim_buf_get_name(bufnr)
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
      vim.lsp.log.info(string.format('Unknown DiagnosticTag %d from LSP client %d', tag, client_id))
    end
  end
  return tags
end

---@param diagnostics lsp.Diagnostic[]
---@param bufnr integer
---@param client_id integer
---@return vim.Diagnostic[]
local function diagnostic_lsp_to_vim(diagnostics, bufnr, client_id)
  local buf_lines = get_buf_lines(bufnr)
  local client = vim.lsp.get_client_by_id(client_id)
  local position_encoding = client and client.offset_encoding or 'utf-16'
  --- @param diagnostic lsp.Diagnostic
  --- @return vim.Diagnostic
  return vim.tbl_map(function(diagnostic)
    local start = diagnostic.range.start
    local _end = diagnostic.range['end']
    local message = diagnostic.message
    if type(message) ~= 'string' then
      vim.notify_once(
        string.format('Unsupported Markup message from LSP client %d', client_id),
        vim.lsp.log_levels.ERROR
      )
      --- @diagnostic disable-next-line: undefined-field,no-unknown
      message = diagnostic.message.value
    end
    local line = buf_lines and buf_lines[start.line + 1] or ''
    --- @type vim.Diagnostic
    return {
      lnum = start.line,
      col = vim.str_byteindex(line, position_encoding, start.character, false),
      end_lnum = _end.line,
      end_col = vim.str_byteindex(line, position_encoding, _end.character, false),
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
local _client_push_namespaces = {}

---@type table<string, integer>
local _client_pull_namespaces = {}

--- Get the diagnostic namespace associated with an LSP client |vim.diagnostic| for diagnostics
---
---@param client_id integer The id of the LSP client
---@param is_pull boolean? Whether the namespace is for a pull or push client. Defaults to push
function M.get_namespace(client_id, is_pull)
  vim.validate('client_id', client_id, 'number')

  local client = vim.lsp.get_client_by_id(client_id)
  if is_pull then
    local server_id =
      vim.tbl_get((client or {}).server_capabilities, 'diagnosticProvider', 'identifier')
    local key = string.format('%d:%s', client_id, server_id or 'nil')
    local name = string.format(
      'vim.lsp.%s.%d.%s',
      client and client.name or 'unknown',
      client_id,
      server_id or 'nil'
    )
    local ns = _client_pull_namespaces[key]
    if not ns then
      ns = api.nvim_create_namespace(name)
      _client_pull_namespaces[key] = ns
    end
    return ns
  else
    local name = string.format('vim.lsp.%s.%d', client and client.name or 'unknown', client_id)
    local ns = _client_push_namespaces[client_id]
    if not ns then
      ns = api.nvim_create_namespace(name)
      _client_push_namespaces[client_id] = ns
    end
    return ns
  end
end

local function convert_severity(opt)
  if type(opt) == 'table' and not opt.severity and opt.severity_limit then
    vim.deprecate('severity_limit', '{min = severity} See vim.diagnostic.severity', '0.11')
    opt.severity = { min = severity_lsp_to_vim(opt.severity_limit) }
  end
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

  if client_id == nil then
    client_id = DEFAULT_CLIENT_ID
  end

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
      local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
      client:request(ctx.method, ctx.params)
    end
    return
  end

  if result == nil or result.kind == 'unchanged' then
    return
  end

  handle_diagnostics(ctx.params.textDocument.uri, ctx.client_id, result.items, true)
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
  convert_severity(opts)
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
--- @private
local function clear(bufnr)
  for _, namespace in pairs(_client_pull_namespaces) do
    vim.diagnostic.reset(namespace, bufnr)
  end
end

---@class (private) lsp.diagnostic.bufstate
---@field enabled boolean Whether inlay hints are enabled for this buffer
---@type table<integer, lsp.diagnostic.bufstate>
local bufstates = {}

--- Disable pull diagnostics for a buffer
--- @param bufnr integer
--- @private
local function disable(bufnr)
  local bufstate = bufstates[bufnr]
  if bufstate then
    bufstate.enabled = false
  end
  clear(bufnr)
end

--- Refresh diagnostics, only if we have attached clients that support it
---@param bufnr (integer) buffer number
---@param opts? table Additional options to pass to util._refresh
---@private
local function _refresh(bufnr, opts)
  opts = opts or {}
  opts['bufnr'] = bufnr
  vim.lsp.util._refresh(ms.textDocument_diagnostic, opts)
end

--- Enable pull diagnostics for a buffer
---@param bufnr (integer) Buffer handle, or 0 for current
---@private
function M._enable(bufnr)
  bufnr = vim._resolve_bufnr(bufnr)

  if not bufstates[bufnr] then
    bufstates[bufnr] = { enabled = true }

    api.nvim_create_autocmd('LspNotify', {
      buffer = bufnr,
      callback = function(opts)
        if
          opts.data.method ~= ms.textDocument_didChange
          and opts.data.method ~= ms.textDocument_didOpen
        then
          return
        end
        if bufstates[bufnr] and bufstates[bufnr].enabled then
          local client_id = opts.data.client_id --- @type integer?
          _refresh(bufnr, { only_visible = true, client_id = client_id })
        end
      end,
      group = augroup,
    })

    api.nvim_buf_attach(bufnr, false, {
      on_reload = function()
        if bufstates[bufnr] and bufstates[bufnr].enabled then
          _refresh(bufnr)
        end
      end,
      on_detach = function()
        disable(bufnr)
      end,
    })

    api.nvim_create_autocmd('LspDetach', {
      buffer = bufnr,
      callback = function(args)
        local clients = vim.lsp.get_clients({ bufnr = bufnr, method = ms.textDocument_diagnostic })

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
  else
    bufstates[bufnr].enabled = true
  end
end

return M
