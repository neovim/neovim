---@brief lsp-diagnostic

local protocol = require('vim.lsp.protocol')

local M = {}

local DEFAULT_CLIENT_ID = -1
---@private
local function get_client_id(client_id)
  if client_id == nil then
    client_id = DEFAULT_CLIENT_ID
  end

  return client_id
end

---@private
---@param severity lsp.DiagnosticSeverity
local function severity_lsp_to_vim(severity)
  if type(severity) == 'string' then
    severity = protocol.DiagnosticSeverity[severity]
  end
  return severity
end

---@private
---@return lsp.DiagnosticSeverity
local function severity_vim_to_lsp(severity)
  if type(severity) == 'string' then
    severity = vim.diagnostic.severity[severity]
  end
  return severity
end

---@private
---@return integer
local function line_byte_from_position(lines, lnum, col, offset_encoding)
  if not lines or offset_encoding == 'utf-8' then
    return col
  end

  local line = lines[lnum + 1]
  local ok, result = pcall(vim.str_byteindex, line, col, offset_encoding == 'utf-16')
  if ok then
    return result
  end

  return col
end

---@private
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

--- @private
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
      vim.notify_once(
        string.format('Unknown DiagnosticTag %d from LSP client %d', tag, client_id),
        vim.log.levels.WARN
      )
    end
  end
  return tags
end

---@private
---@param diagnostics lsp.Diagnostic[]
---@param bufnr integer
---@param client_id integer
---@return Diagnostic[]
local function diagnostic_lsp_to_vim(diagnostics, bufnr, client_id)
  local buf_lines = get_buf_lines(bufnr)
  local client = vim.lsp.get_client_by_id(client_id)
  local offset_encoding = client and client.offset_encoding or 'utf-16'
  ---@diagnostic disable-next-line:no-unknown
  return vim.tbl_map(function(diagnostic)
    ---@cast diagnostic lsp.Diagnostic
    local start = diagnostic.range.start
    local _end = diagnostic.range['end']
    return {
      lnum = start.line,
      col = line_byte_from_position(buf_lines, start.line, start.character, offset_encoding),
      end_lnum = _end.line,
      end_col = line_byte_from_position(buf_lines, _end.line, _end.character, offset_encoding),
      severity = severity_lsp_to_vim(diagnostic.severity),
      message = diagnostic.message,
      source = diagnostic.source,
      code = diagnostic.code,
      _tags = tags_lsp_to_vim(diagnostic, client_id),
      user_data = {
        lsp = {
          -- usage of user_data.lsp.code is deprecated in favor of the top-level code field
          code = diagnostic.code,
          codeDescription = diagnostic.codeDescription,
          relatedInformation = diagnostic.relatedInformation,
          data = diagnostic.data,
        },
      },
    }
  end, diagnostics)
end

--- @private
--- @param diagnostics Diagnostic[]
--- @return lsp.Diagnostic[]
local function diagnostic_vim_to_lsp(diagnostics)
  ---@diagnostic disable-next-line:no-unknown
  return vim.tbl_map(function(diagnostic)
    ---@cast diagnostic Diagnostic
    return vim.tbl_extend('keep', {
      -- "keep" the below fields over any duplicate fields in diagnostic.user_data.lsp
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
    }, diagnostic.user_data and (diagnostic.user_data.lsp or {}) or {})
  end, diagnostics)
end

---@type table<integer,integer>
local _client_namespaces = {}

--- Get the diagnostic namespace associated with an LSP client |vim.diagnostic|.
---
---@param client_id integer The id of the LSP client
function M.get_namespace(client_id)
  vim.validate({ client_id = { client_id, 'n' } })
  if not _client_namespaces[client_id] then
    local client = vim.lsp.get_client_by_id(client_id)
    local name = string.format('vim.lsp.%s.%d', client and client.name or 'unknown', client_id)
    _client_namespaces[client_id] = vim.api.nvim_create_namespace(name)
  end
  return _client_namespaces[client_id]
end

--- |lsp-handler| for the method "textDocument/publishDiagnostics"
---
--- See |vim.diagnostic.config()| for configuration options. Handler-specific
--- configuration can be set using |vim.lsp.with()|:
--- <pre>lua
--- vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(
---   vim.lsp.diagnostic.on_publish_diagnostics, {
---     -- Enable underline, use default values
---     underline = true,
---     -- Enable virtual text, override spacing to 4
---     virtual_text = {
---       spacing = 4,
---     },
---     -- Use a function to dynamically turn signs off
---     -- and on, using buffer local variables
---     signs = function(namespace, bufnr)
---       return vim.b[bufnr].show_signs == true
---     end,
---     -- Disable a feature
---     update_in_insert = false,
---   }
--- )
--- </pre>
---
---@param config table Configuration table (see |vim.diagnostic.config()|).
function M.on_publish_diagnostics(_, result, ctx, config)
  local client_id = ctx.client_id
  local uri = result.uri
  local fname = vim.uri_to_fname(uri)
  local diagnostics = result.diagnostics
  if #diagnostics == 0 and vim.fn.bufexists(fname) == 0 then
    return
  end
  local bufnr = vim.fn.bufadd(fname)

  if not bufnr then
    return
  end

  client_id = get_client_id(client_id)
  local namespace = M.get_namespace(client_id)

  if config then
    for _, opt in pairs(config) do
      if type(opt) == 'table' then
        if not opt.severity and opt.severity_limit then
          opt.severity = { min = severity_lsp_to_vim(opt.severity_limit) }
        end
      end
    end

    -- Persist configuration to ensure buffer reloads use the same
    -- configuration. To make lsp.with configuration work (See :help
    -- lsp-handler-configuration)
    vim.diagnostic.config(config, namespace)
  end

  vim.diagnostic.set(namespace, bufnr, diagnostic_lsp_to_vim(diagnostics, bufnr, client_id))
end

--- Clear diagnostics and diagnostic cache.
---
--- Diagnostic producers should prefer |vim.diagnostic.reset()|. However,
--- this method signature is still used internally in some parts of the LSP
--- implementation so it's simply marked @private rather than @deprecated.
---
---@param client_id integer
---@param buffer_client_map table map of buffers to active clients
---@private
function M.reset(client_id, buffer_client_map)
  buffer_client_map = vim.deepcopy(buffer_client_map)
  vim.schedule(function()
    for bufnr, client_ids in pairs(buffer_client_map) do
      if client_ids[client_id] then
        local namespace = M.get_namespace(client_id)
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
---@param opts table|nil Configuration keys
---         - severity: (DiagnosticSeverity, default nil)
---             - Only return diagnostics with this severity. Overrides severity_limit
---         - severity_limit: (DiagnosticSeverity, default nil)
---             - Limit severity of diagnostics found. E.g. "Warning" means { "Error", "Warning" } will be valid.
---@param client_id integer|nil the client id
---@return table Table with map of line number to list of diagnostics.
---              Structured: { [1] = {...}, [5] = {.... } }
---@private
function M.get_line_diagnostics(bufnr, line_nr, opts, client_id)
  opts = opts or {}
  if opts.severity then
    opts.severity = severity_lsp_to_vim(opts.severity)
  elseif opts.severity_limit then
    opts.severity = { min = severity_lsp_to_vim(opts.severity_limit) }
  end

  if client_id then
    opts.namespace = M.get_namespace(client_id)
  end

  if not line_nr then
    line_nr = vim.api.nvim_win_get_cursor(0)[1] - 1
  end

  opts.lnum = line_nr

  return diagnostic_vim_to_lsp(vim.diagnostic.get(bufnr, opts))
end

return M
