---@brief lsp-diagnostic
---
---@class Diagnostic
---@field range Range
---@field message string
---@field severity DiagnosticSeverity|nil
---@field code number | string
---@field source string
---@field tags DiagnosticTag[]
---@field relatedInformation DiagnosticRelatedInformation[]

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
local function get_bufnr(bufnr)
  if not bufnr then
    return vim.api.nvim_get_current_buf()
  elseif bufnr == 0 then
    return vim.api.nvim_get_current_buf()
  end

  return bufnr
end

---@private
local function severity_lsp_to_vim(severity)
  if type(severity) == 'string' then
    severity = vim.lsp.protocol.DiagnosticSeverity[severity]
  end
  return severity
end

---@private
local function severity_vim_to_lsp(severity)
  if type(severity) == 'string' then
    severity = vim.diagnostic.severity[severity]
  end
  return severity
end

---@private
local function line_byte_from_position(lines, lnum, col, offset_encoding)
  if not lines or offset_encoding == "utf-8" then
    return col
  end

  local line = lines[lnum + 1]
  local ok, result = pcall(vim.str_byteindex, line, col, offset_encoding == "utf-16")
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

  local content = f:read("*a")
  if not content then
    -- Some LSP servers report diagnostics at a directory level, in which case
    -- io.read() returns nil
    f:close()
    return
  end

  local lines = vim.split(content, "\n")
  f:close()
  return lines
end

---@private
local function diagnostic_lsp_to_vim(diagnostics, bufnr, client_id)
  local buf_lines = get_buf_lines(bufnr)
  local client = vim.lsp.get_client_by_id(client_id)
  local offset_encoding = client and client.offset_encoding or "utf-16"
  return vim.tbl_map(function(diagnostic)
    local start = diagnostic.range.start
    local _end = diagnostic.range["end"]
    return {
      lnum = start.line,
      col = line_byte_from_position(buf_lines, start.line, start.character, offset_encoding),
      end_lnum = _end.line,
      end_col = line_byte_from_position(buf_lines, _end.line, _end.character, offset_encoding),
      severity = severity_lsp_to_vim(diagnostic.severity),
      message = diagnostic.message,
      source = diagnostic.source,
      code = diagnostic.code,
      user_data = {
        lsp = {
          -- usage of user_data.lsp.code is deprecated in favor of the top-level code field
          code = diagnostic.code,
          codeDescription = diagnostic.codeDescription,
          tags = diagnostic.tags,
          relatedInformation = diagnostic.relatedInformation,
          data = diagnostic.data,
        },
      },
    }
  end, diagnostics)
end

---@private
local function diagnostic_vim_to_lsp(diagnostics)
  return vim.tbl_map(function(diagnostic)
    return vim.tbl_extend("keep", {
      -- "keep" the below fields over any duplicate fields in diagnostic.user_data.lsp
      range = {
        start = {
          line = diagnostic.lnum,
          character = diagnostic.col,
        },
        ["end"] = {
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

local _client_namespaces = {}

--- Get the diagnostic namespace associated with an LSP client |vim.diagnostic|.
---
---@param client_id number The id of the LSP client
function M.get_namespace(client_id)
  vim.validate { client_id = { client_id, 'n' } }
  if not _client_namespaces[client_id] then
    local client = vim.lsp.get_client_by_id(client_id)
    local name = string.format("vim.lsp.%s.%d", client and client.name or "unknown", client_id)
    _client_namespaces[client_id] = vim.api.nvim_create_namespace(name)
  end
  return _client_namespaces[client_id]
end

--- |lsp-handler| for the method "textDocument/publishDiagnostics"
---
--- See |vim.diagnostic.config()| for configuration options. Handler-specific
--- configuration can be set using |vim.lsp.with()|:
--- <pre>
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
          opt.severity = {min=severity_lsp_to_vim(opt.severity_limit)}
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
---@param client_id number
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

-- Deprecated Functions {{{


--- Save diagnostics to the current buffer.
---
---@deprecated Prefer |vim.diagnostic.set()|
---
--- Handles saving diagnostics from multiple clients in the same buffer.
---@param diagnostics Diagnostic[]
---@param bufnr number
---@param client_id number
---@private
function M.save(diagnostics, bufnr, client_id)
  vim.notify_once('vim.lsp.diagnostic.save is deprecated. See :h deprecated', vim.log.levels.WARN)
  local namespace = M.get_namespace(client_id)
  vim.diagnostic.set(namespace, bufnr, diagnostic_lsp_to_vim(diagnostics, bufnr, client_id))
end
-- }}}

--- Get all diagnostics for clients
---
---@deprecated Prefer |vim.diagnostic.get()|
---
---@param client_id number Restrict included diagnostics to the client
---                        If nil, diagnostics of all clients are included.
---@return table with diagnostics grouped by bufnr (bufnr: Diagnostic[])
function M.get_all(client_id)
  vim.notify_once('vim.lsp.diagnostic.get_all is deprecated. See :h deprecated', vim.log.levels.WARN)
  local result = {}
  local namespace
  if client_id then
    namespace = M.get_namespace(client_id)
  end
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    local diagnostics = diagnostic_vim_to_lsp(vim.diagnostic.get(bufnr, {namespace = namespace}))
    result[bufnr] = diagnostics
  end
  return result
end

--- Return associated diagnostics for bufnr
---
---@deprecated Prefer |vim.diagnostic.get()|
---
---@param bufnr number
---@param client_id number|nil If nil, then return all of the diagnostics.
---                            Else, return just the diagnostics associated with the client_id.
---@param predicate function|nil Optional function for filtering diagnostics
function M.get(bufnr, client_id, predicate)
  vim.notify_once('vim.lsp.diagnostic.get is deprecated. See :h deprecated', vim.log.levels.WARN)
  predicate = predicate or function() return true end
  if client_id == nil then
    local all_diagnostics = {}
    vim.lsp.for_each_buffer_client(bufnr, function(_, iter_client_id, _)
      local iter_diagnostics = vim.tbl_filter(predicate, M.get(bufnr, iter_client_id))
      for _, diagnostic in ipairs(iter_diagnostics) do
        table.insert(all_diagnostics, diagnostic)
      end
    end)
    return all_diagnostics
  end

  local namespace = M.get_namespace(client_id)
  return diagnostic_vim_to_lsp(vim.tbl_filter(predicate, vim.diagnostic.get(bufnr, {namespace=namespace})))
end

--- Get the diagnostics by line
---
--- Marked private as this is used internally by the LSP subsystem, but
--- most users should instead prefer |vim.diagnostic.get()|.
---
---@param bufnr number|nil The buffer number
---@param line_nr number|nil The line number
---@param opts table|nil Configuration keys
---         - severity: (DiagnosticSeverity, default nil)
---             - Only return diagnostics with this severity. Overrides severity_limit
---         - severity_limit: (DiagnosticSeverity, default nil)
---             - Limit severity of diagnostics found. E.g. "Warning" means { "Error", "Warning" } will be valid.
---@param client_id|nil number the client id
---@return table Table with map of line number to list of diagnostics.
---              Structured: { [1] = {...}, [5] = {.... } }
---@private
function M.get_line_diagnostics(bufnr, line_nr, opts, client_id)
  opts = opts or {}
  if opts.severity then
    opts.severity = severity_lsp_to_vim(opts.severity)
  elseif opts.severity_limit then
    opts.severity = {min=severity_lsp_to_vim(opts.severity_limit)}
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

--- Get the counts for a particular severity
---
---@deprecated Prefer |vim.diagnostic.get_count()|
---
---@param bufnr number The buffer number
---@param severity DiagnosticSeverity
---@param client_id number the client id
function M.get_count(bufnr, severity, client_id)
  vim.notify_once('vim.lsp.diagnostic.get_count is deprecated. See :h deprecated', vim.log.levels.WARN)
  severity = severity_lsp_to_vim(severity)
  local opts = { severity = severity }
  if client_id ~= nil then
    opts.namespace = M.get_namespace(client_id)
  end

  return #vim.diagnostic.get(bufnr, opts)
end

--- Get the previous diagnostic closest to the cursor_position
---
---@deprecated Prefer |vim.diagnostic.get_prev()|
---
---@param opts table See |vim.lsp.diagnostic.goto_next()|
---@return table Previous diagnostic
function M.get_prev(opts)
  vim.notify_once('vim.lsp.diagnostic.get_prev is deprecated. See :h deprecated', vim.log.levels.WARN)
  if opts then
    if opts.severity then
      opts.severity = severity_lsp_to_vim(opts.severity)
    elseif opts.severity_limit then
      opts.severity = {min=severity_lsp_to_vim(opts.severity_limit)}
    end
  end
  return diagnostic_vim_to_lsp({vim.diagnostic.get_prev(opts)})[1]
end

--- Return the pos, {row, col}, for the prev diagnostic in the current buffer.
---
---@deprecated Prefer |vim.diagnostic.get_prev_pos()|
---
---@param opts table See |vim.lsp.diagnostic.goto_next()|
---@return table Previous diagnostic position
function M.get_prev_pos(opts)
  vim.notify_once('vim.lsp.diagnostic.get_prev_pos is deprecated. See :h deprecated', vim.log.levels.WARN)
  if opts then
    if opts.severity then
      opts.severity = severity_lsp_to_vim(opts.severity)
    elseif opts.severity_limit then
      opts.severity = {min=severity_lsp_to_vim(opts.severity_limit)}
    end
  end
  return vim.diagnostic.get_prev_pos(opts)
end

--- Move to the previous diagnostic
---
---@deprecated Prefer |vim.diagnostic.goto_prev()|
---
---@param opts table See |vim.lsp.diagnostic.goto_next()|
function M.goto_prev(opts)
  vim.notify_once('vim.lsp.diagnostic.goto_prev is deprecated. See :h deprecated', vim.log.levels.WARN)
  if opts then
    if opts.severity then
      opts.severity = severity_lsp_to_vim(opts.severity)
    elseif opts.severity_limit then
      opts.severity = {min=severity_lsp_to_vim(opts.severity_limit)}
    end
  end
  return vim.diagnostic.goto_prev(opts)
end

--- Get the next diagnostic closest to the cursor_position
---
---@deprecated Prefer |vim.diagnostic.get_next()|
---
---@param opts table See |vim.lsp.diagnostic.goto_next()|
---@return table Next diagnostic
function M.get_next(opts)
  vim.notify_once('vim.lsp.diagnostic.get_next is deprecated. See :h deprecated', vim.log.levels.WARN)
  if opts then
    if opts.severity then
      opts.severity = severity_lsp_to_vim(opts.severity)
    elseif opts.severity_limit then
      opts.severity = {min=severity_lsp_to_vim(opts.severity_limit)}
    end
  end
  return diagnostic_vim_to_lsp({vim.diagnostic.get_next(opts)})[1]
end

--- Return the pos, {row, col}, for the next diagnostic in the current buffer.
---
---@deprecated Prefer |vim.diagnostic.get_next_pos()|
---
---@param opts table See |vim.lsp.diagnostic.goto_next()|
---@return table Next diagnostic position
function M.get_next_pos(opts)
  vim.notify_once('vim.lsp.diagnostic.get_next_pos is deprecated. See :h deprecated', vim.log.levels.WARN)
  if opts then
    if opts.severity then
      opts.severity = severity_lsp_to_vim(opts.severity)
    elseif opts.severity_limit then
      opts.severity = {min=severity_lsp_to_vim(opts.severity_limit)}
    end
  end
  return vim.diagnostic.get_next_pos(opts)
end

--- Move to the next diagnostic
---
---@deprecated Prefer |vim.diagnostic.goto_next()|
function M.goto_next(opts)
  vim.notify_once('vim.lsp.diagnostic.goto_next is deprecated. See :h deprecated', vim.log.levels.WARN)
  if opts then
    if opts.severity then
      opts.severity = severity_lsp_to_vim(opts.severity)
    elseif opts.severity_limit then
      opts.severity = {min=severity_lsp_to_vim(opts.severity_limit)}
    end
  end
  return vim.diagnostic.goto_next(opts)
end

--- Set signs for given diagnostics
---
---@deprecated Prefer |vim.diagnostic._set_signs()|
---
---@param diagnostics Diagnostic[]
---@param bufnr number The buffer number
---@param client_id number the client id
---@param sign_ns number|nil
---@param opts table Configuration for signs. Keys:
---             - priority: Set the priority of the signs.
---             - severity_limit (DiagnosticSeverity):
---                 - Limit severity of diagnostics found. E.g. "Warning" means { "Error", "Warning" } will be valid.
function M.set_signs(diagnostics, bufnr, client_id, _, opts)
  vim.notify_once('vim.lsp.diagnostic.set_signs is deprecated. See :h deprecated', vim.log.levels.WARN)
  local namespace = M.get_namespace(client_id)
  if opts and not opts.severity and opts.severity_limit then
    opts.severity = {min=severity_lsp_to_vim(opts.severity_limit)}
  end

  vim.diagnostic._set_signs(namespace, bufnr, diagnostic_lsp_to_vim(diagnostics, bufnr, client_id), opts)
end

--- Set underline for given diagnostics
---
---@deprecated Prefer |vim.diagnostic._set_underline()|
---
---@param diagnostics Diagnostic[]
---@param bufnr number: The buffer number
---@param client_id number: The client id
---@param diagnostic_ns number|nil: The namespace
---@param opts table: Configuration table:
---             - severity_limit (DiagnosticSeverity):
---                 - Limit severity of diagnostics found. E.g. "Warning" means { "Error", "Warning" } will be valid.
function M.set_underline(diagnostics, bufnr, client_id, _, opts)
  vim.notify_once('vim.lsp.diagnostic.set_underline is deprecated. See :h deprecated', vim.log.levels.WARN)
  local namespace = M.get_namespace(client_id)
  if opts and not opts.severity and opts.severity_limit then
    opts.severity = {min=severity_lsp_to_vim(opts.severity_limit)}
  end
  return vim.diagnostic._set_underline(namespace, bufnr, diagnostic_lsp_to_vim(diagnostics, bufnr, client_id), opts)
end

--- Set virtual text given diagnostics
---
---@deprecated Prefer |vim.diagnostic._set_virtual_text()|
---
---@param diagnostics Diagnostic[]
---@param bufnr number
---@param client_id number
---@param diagnostic_ns number
---@param opts table Options on how to display virtual text. Keys:
---             - prefix (string): Prefix to display before virtual text on line
---             - spacing (number): Number of spaces to insert before virtual text
---             - severity_limit (DiagnosticSeverity):
---                 - Limit severity of diagnostics found. E.g. "Warning" means { "Error", "Warning" } will be valid.
function M.set_virtual_text(diagnostics, bufnr, client_id, _, opts)
  vim.notify_once('vim.lsp.diagnostic.set_virtual_text is deprecated. See :h deprecated', vim.log.levels.WARN)
  local namespace = M.get_namespace(client_id)
  if opts and not opts.severity and opts.severity_limit then
    opts.severity = {min=severity_lsp_to_vim(opts.severity_limit)}
  end
  return vim.diagnostic._set_virtual_text(namespace, bufnr, diagnostic_lsp_to_vim(diagnostics, bufnr, client_id), opts)
end

--- Default function to get text chunks to display using |nvim_buf_set_extmark()|.
---
---@deprecated Prefer |vim.diagnostic.get_virt_text_chunks()|
---
---@param bufnr number The buffer to display the virtual text in
---@param line number The line number to display the virtual text on
---@param line_diags Diagnostic[] The diagnostics associated with the line
---@param opts table See {opts} from |vim.lsp.diagnostic.set_virtual_text()|
---@return an array of [text, hl_group] arrays. This can be passed directly to
---        the {virt_text} option of |nvim_buf_set_extmark()|.
function M.get_virtual_text_chunks_for_line(bufnr, _, line_diags, opts)
  vim.notify_once('vim.lsp.diagnostic.get_virtual_text_chunks_for_line is deprecated. See :h deprecated', vim.log.levels.WARN)
  return vim.diagnostic._get_virt_text_chunks(diagnostic_lsp_to_vim(line_diags, bufnr), opts)
end

--- Open a floating window with the diagnostics from {position}
---
---@deprecated Prefer |vim.diagnostic.show_position_diagnostics()|
---
---@param opts table|nil Configuration keys
---         - severity: (DiagnosticSeverity, default nil)
---             - Only return diagnostics with this severity. Overrides severity_limit
---         - severity_limit: (DiagnosticSeverity, default nil)
---             - Limit severity of diagnostics found. E.g. "Warning" means { "Error", "Warning" } will be valid.
---         - all opts for |show_diagnostics()| can be used here
---@param buf_nr number|nil The buffer number
---@param position table|nil The (0,0)-indexed position
---@return table {popup_bufnr, win_id}
function M.show_position_diagnostics(opts, buf_nr, position)
  vim.notify_once('vim.lsp.diagnostic.show_position_diagnostics is deprecated. See :h deprecated', vim.log.levels.WARN)
  opts = opts or {}
  opts.scope = "cursor"
  opts.pos = position
  if opts.severity then
    opts.severity = severity_lsp_to_vim(opts.severity)
  elseif opts.severity_limit then
    opts.severity = {min=severity_lsp_to_vim(opts.severity_limit)}
  end
  return vim.diagnostic.open_float(buf_nr, opts)
end

--- Open a floating window with the diagnostics from {line_nr}
---
---@deprecated Prefer |vim.diagnostic.open_float()|
---
---@param opts table Configuration table
---     - all opts for |vim.lsp.diagnostic.get_line_diagnostics()| and
---          |show_diagnostics()| can be used here
---@param buf_nr number|nil The buffer number
---@param line_nr number|nil The line number
---@param client_id number|nil the client id
---@return table {popup_bufnr, win_id}
function M.show_line_diagnostics(opts, buf_nr, line_nr, client_id)
  vim.notify_once('vim.lsp.diagnostic.show_line_diagnostics is deprecated. See :h deprecated', vim.log.levels.WARN)
  opts = opts or {}
  opts.scope = "line"
  opts.pos = line_nr
  if client_id then
    opts.namespace = M.get_namespace(client_id)
  end
  return vim.diagnostic.open_float(buf_nr, opts)
end

--- Redraw diagnostics for the given buffer and client
---
---@deprecated Prefer |vim.diagnostic.show()|
---
--- This calls the "textDocument/publishDiagnostics" handler manually using
--- the cached diagnostics already received from the server. This can be useful
--- for redrawing diagnostics after making changes in diagnostics
--- configuration. |lsp-handler-configuration|
---
---@param bufnr (optional, number): Buffer handle, defaults to current
---@param client_id (optional, number): Redraw diagnostics for the given
---       client. The default is to redraw diagnostics for all attached
---       clients.
function M.redraw(bufnr, client_id)
  vim.notify_once('vim.lsp.diagnostic.redraw is deprecated. See :h deprecated', vim.log.levels.WARN)
  bufnr = get_bufnr(bufnr)
  if not client_id then
    return vim.lsp.for_each_buffer_client(bufnr, function(client)
      M.redraw(bufnr, client.id)
    end)
  end

  local namespace = M.get_namespace(client_id)
  return vim.diagnostic.show(namespace, bufnr)
end

--- Sets the quickfix list
---
---@deprecated Prefer |vim.diagnostic.setqflist()|
---
---@param opts table|nil Configuration table. Keys:
---         - {open}: (boolean, default true)
---             - Open quickfix list after set
---         - {client_id}: (number)
---             - If nil, will consider all clients attached to buffer.
---         - {severity}: (DiagnosticSeverity)
---             - Exclusive severity to consider. Overrides {severity_limit}
---         - {severity_limit}: (DiagnosticSeverity)
---             - Limit severity of diagnostics found. E.g. "Warning" means { "Error", "Warning" } will be valid.
---         - {workspace}: (boolean, default true)
---             - Set the list with workspace diagnostics
function M.set_qflist(opts)
  vim.notify_once('vim.lsp.diagnostic.set_qflist is deprecated. See :h deprecated', vim.log.levels.WARN)
  opts = opts or {}
  if opts.severity then
    opts.severity = severity_lsp_to_vim(opts.severity)
  elseif opts.severity_limit then
    opts.severity = {min=severity_lsp_to_vim(opts.severity_limit)}
  end
  if opts.client_id then
    opts.client_id = nil
    opts.namespace = M.get_namespace(opts.client_id)
  end
  local workspace = vim.F.if_nil(opts.workspace, true)
  opts.bufnr = not workspace and 0
  return vim.diagnostic.setqflist(opts)
end

--- Sets the location list
---
---@deprecated Prefer |vim.diagnostic.setloclist()|
---
---@param opts table|nil Configuration table. Keys:
---         - {open}: (boolean, default true)
---             - Open loclist after set
---         - {client_id}: (number)
---             - If nil, will consider all clients attached to buffer.
---         - {severity}: (DiagnosticSeverity)
---             - Exclusive severity to consider. Overrides {severity_limit}
---         - {severity_limit}: (DiagnosticSeverity)
---             - Limit severity of diagnostics found. E.g. "Warning" means { "Error", "Warning" } will be valid.
---         - {workspace}: (boolean, default false)
---             - Set the list with workspace diagnostics
function M.set_loclist(opts)
  vim.notify_once('vim.lsp.diagnostic.set_loclist is deprecated. See :h deprecated', vim.log.levels.WARN)
  opts = opts or {}
  if opts.severity then
    opts.severity = severity_lsp_to_vim(opts.severity)
  elseif opts.severity_limit then
    opts.severity = {min=severity_lsp_to_vim(opts.severity_limit)}
  end
  if opts.client_id then
    opts.client_id = nil
    opts.namespace = M.get_namespace(opts.client_id)
  end
  local workspace = vim.F.if_nil(opts.workspace, false)
  opts.bufnr = not workspace and 0
  return vim.diagnostic.setloclist(opts)
end

--- Disable diagnostics for the given buffer and client
---
---@deprecated Prefer |vim.diagnostic.disable()|
---
---@param bufnr (optional, number): Buffer handle, defaults to current
---@param client_id (optional, number): Disable diagnostics for the given
---       client. The default is to disable diagnostics for all attached
---       clients.
-- Note that when diagnostics are disabled for a buffer, the server will still
-- send diagnostic information and the client will still process it. The
-- diagnostics are simply not displayed to the user.
function M.disable(bufnr, client_id)
  vim.notify_once('vim.lsp.diagnostic.disable is deprecated. See :h deprecated', vim.log.levels.WARN)
  if not client_id then
    return vim.lsp.for_each_buffer_client(bufnr, function(client)
      M.disable(bufnr, client.id)
    end)
  end

  bufnr = get_bufnr(bufnr)
  local namespace = M.get_namespace(client_id)
  return vim.diagnostic.disable(bufnr, namespace)
end

--- Enable diagnostics for the given buffer and client
---
---@deprecated Prefer |vim.diagnostic.enable()|
---
---@param bufnr (optional, number): Buffer handle, defaults to current
---@param client_id (optional, number): Enable diagnostics for the given
---       client. The default is to enable diagnostics for all attached
---       clients.
function M.enable(bufnr, client_id)
  vim.notify_once('vim.lsp.diagnostic.enable is deprecated. See :h deprecated', vim.log.levels.WARN)
  if not client_id then
    return vim.lsp.for_each_buffer_client(bufnr, function(client)
      M.enable(bufnr, client.id)
    end)
  end

  bufnr = get_bufnr(bufnr)
  local namespace = M.get_namespace(client_id)
  return vim.diagnostic.enable(bufnr, namespace)
end

-- }}}

return M
