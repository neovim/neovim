local api = vim.api
local validate = vim.validate

local highlight = vim.highlight
local log = require('vim.lsp.log')
local protocol = require('vim.lsp.protocol')
local util = require('vim.lsp.util')

local if_nil = vim.F.if_nil

--@class DiagnosticSeverity
local DiagnosticSeverity = protocol.DiagnosticSeverity

local to_severity = function(severity)
  if not severity then return nil end
  return type(severity) == 'string' and DiagnosticSeverity[severity] or severity
end

local filter_to_severity_limit = function(severity, diagnostics)
  local filter_level = to_severity(severity)
  if not filter_level then
    return diagnostics
  end

  return vim.tbl_filter(function(t) return t.severity == filter_level end, diagnostics)
end

local filter_by_severity_limit = function(severity_limit, diagnostics)
  local filter_level = to_severity(severity_limit)
  if not filter_level then
    return diagnostics
  end

  return vim.tbl_filter(function(t) return t.severity <= filter_level end, diagnostics)
end

local to_position = function(position, bufnr)
  vim.validate { position = {position, 't'} }

  return {
    position.line,
    util._get_line_byte_from_position(bufnr, position)
  }
end


---@brief lsp-diagnostic
---
--@class Diagnostic
--@field range Range
--@field message string
--@field severity DiagnosticSeverity|nil
--@field code number | string
--@field source string
--@field tags DiagnosticTag[]
--@field relatedInformation DiagnosticRelatedInformation[]

local M = {}

-- Diagnostic Highlights {{{

-- TODO(tjdevries): Determine how to generate documentation for these
--                  and how to configure them to be easy for users.
--
--                  For now, just use the following script. It should work pretty good.
--[[
local levels = {"Error", "Warning", "Information", "Hint" }

local all_info = {
  { "Default", "Used as the base highlight group, other highlight groups link to", },
  { "VirtualText", 'Used for "%s" diagnostic virtual text.\n  See |vim.lsp.diagnostic.set_virtual_text()|', },
  { "Underline", 'Used to underline "%s" diagnostics.\n  See |vim.lsp.diagnostic.set_underline()|', },
  { "Floating", 'Used to color "%s" diagnostic messages in diagnostics float.\n  See |vim.lsp.diagnostic.show_line_diagnostics()|', },
  { "Sign", 'Used for "%s" signs in sing column.\n  See |vim.lsp.diagnostic.set_signs()|', },
}

local results = {}
for _, info in ipairs(all_info) do
  for _, level in ipairs(levels) do
    local name = info[1]
    local description = info[2]
    local fullname = string.format("Lsp%s%s", name, level)
    table.insert(results, string.format(
      "%78s", string.format("*hl-%s*", fullname))
    )

    table.insert(results, fullname)
    table.insert(results, string.format("  %s", description))
    table.insert(results, "")
  end
end

-- print(table.concat(results, '\n'))
vim.fn.setreg("*", table.concat(results, '\n'))
--]]

local diagnostic_severities = {
  [DiagnosticSeverity.Error]       = { guifg = "Red" };
  [DiagnosticSeverity.Warning]     = { guifg = "Orange" };
  [DiagnosticSeverity.Information] = { guifg = "LightBlue" };
  [DiagnosticSeverity.Hint]        = { guifg = "LightGrey" };
}

-- Make a map from DiagnosticSeverity -> Highlight Name
local make_highlight_map = function(base_name)
  local result = {}
  for k, _ in pairs(diagnostic_severities) do
    result[k] = "LspDiagnostics" .. base_name .. DiagnosticSeverity[k]
  end

  return result
end

local default_highlight_map = make_highlight_map("Default")
local virtual_text_highlight_map = make_highlight_map("VirtualText")
local underline_highlight_map = make_highlight_map("Underline")
local floating_highlight_map = make_highlight_map("Floating")
local sign_highlight_map = make_highlight_map("Sign")

-- }}}
-- Diagnostic Namespaces {{{
local DEFAULT_CLIENT_ID = -1
local get_client_id = function(client_id)
  if client_id == nil then
    client_id = DEFAULT_CLIENT_ID
  end

  return client_id
end

local get_bufnr = function(bufnr)
  if not bufnr then
    return api.nvim_get_current_buf()
  elseif bufnr == 0 then
    return api.nvim_get_current_buf()
  end

  return bufnr
end


--- Create a namespace table, used to track a client's buffer local items
local _make_namespace_table = function(namespace, api_namespace)
  vim.validate { namespace = { namespace, 's' } }

  return setmetatable({
    [DEFAULT_CLIENT_ID] = api.nvim_create_namespace(namespace)
  }, {
    __index = function(t, client_id)
      client_id = get_client_id(client_id)

      if rawget(t, client_id) == nil then
        local value = string.format("%s:%s", namespace, client_id)

        if api_namespace then
          value = api.nvim_create_namespace(value)
        end

        rawset(t, client_id, value)
      end

      return rawget(t, client_id)
    end
  })
end

local _diagnostic_namespaces = _make_namespace_table("vim_lsp_diagnostics", true)
local _sign_namespaces = _make_namespace_table("vim_lsp_signs", false)

--@private
function M._get_diagnostic_namespace(client_id)
  return _diagnostic_namespaces[client_id]
end

--@private
function M._get_sign_namespace(client_id)
  return _sign_namespaces[client_id]
end
-- }}}
-- Diagnostic Buffer & Client metatables {{{
local bufnr_and_client_cacher_mt = {
  __index = function(t, bufnr)
    if bufnr == 0 or bufnr == nil then
      bufnr = vim.api.nvim_get_current_buf()
    end

    if rawget(t, bufnr) == nil then
      rawset(t, bufnr, {})
    end

    return rawget(t, bufnr)
  end,

  __newindex = function(t, bufnr, v)
    if bufnr == 0 or bufnr == nil then
      bufnr = vim.api.nvim_get_current_buf()
    end

    rawset(t, bufnr, v)
  end,
}
-- }}}
-- Diagnostic Saving & Caching {{{
local _diagnostic_cleanup = setmetatable({}, bufnr_and_client_cacher_mt)
local diagnostic_cache = setmetatable({}, bufnr_and_client_cacher_mt)
local diagnostic_cache_lines = setmetatable({}, bufnr_and_client_cacher_mt)
local diagnostic_cache_counts = setmetatable({}, bufnr_and_client_cacher_mt)

local _bufs_waiting_to_update = setmetatable({}, bufnr_and_client_cacher_mt)

--- Store Diagnostic[] by line
---
---@param diagnostics Diagnostic[]
---@return table<number, Diagnostic[]>
local _diagnostic_lines = function(diagnostics)
  if not diagnostics then return end

  local diagnostics_by_line = {}
  for _, diagnostic in ipairs(diagnostics) do
    local start = diagnostic.range.start
    local line_diagnostics = diagnostics_by_line[start.line]
    if not line_diagnostics then
      line_diagnostics = {}
      diagnostics_by_line[start.line] = line_diagnostics
    end
    table.insert(line_diagnostics, diagnostic)
  end
  return diagnostics_by_line
end

--- Get the count of M by Severity
---
---@param diagnostics Diagnostic[]
---@return table<DiagnosticSeverity, number>
local _diagnostic_counts = function(diagnostics)
  if not diagnostics then return end

  local counts = {}
  for _, diagnostic in pairs(diagnostics) do
    if diagnostic.severity then
      local val = counts[diagnostic.severity]
      if val == nil then
        val = 0
      end

      counts[diagnostic.severity] = val + 1
    end
  end

  return counts
end

--@private
--- Set the different diagnostic cache after `textDocument/publishDiagnostics`
---@param diagnostics Diagnostic[]
---@param bufnr number
---@param client_id number
---@return nil
local function set_diagnostic_cache(diagnostics, bufnr, client_id)
  client_id = get_client_id(client_id)

  -- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#diagnostic
  --
  -- The diagnostic's severity. Can be omitted. If omitted it is up to the
  -- client to interpret diagnostics as error, warning, info or hint.
  -- TODO: Replace this with server-specific heuristics to infer severity.
  local buf_line_count = vim.api.nvim_buf_line_count(bufnr)
  for _, diagnostic in ipairs(diagnostics) do
    if diagnostic.severity == nil then
      diagnostic.severity = DiagnosticSeverity.Error
    end
    -- Account for servers that place diagnostics on terminating newline
    local start = diagnostic.range.start
    start.line = math.min(start.line, buf_line_count - 1)
  end

  diagnostic_cache[bufnr][client_id] = diagnostics
  diagnostic_cache_lines[bufnr][client_id] = _diagnostic_lines(diagnostics)
  diagnostic_cache_counts[bufnr][client_id] = _diagnostic_counts(diagnostics)
end


--@private
--- Clear the cached diagnostics
---@param bufnr number
---@param client_id number
local function clear_diagnostic_cache(bufnr, client_id)
  client_id = get_client_id(client_id)

  diagnostic_cache[bufnr][client_id] = nil
  diagnostic_cache_lines[bufnr][client_id] = nil
  diagnostic_cache_counts[bufnr][client_id] = nil
end

--- Save diagnostics to the current buffer.
---
--- Handles saving diagnostics from multiple clients in the same buffer.
---@param diagnostics Diagnostic[]
---@param bufnr number
---@param client_id number
function M.save(diagnostics, bufnr, client_id)
  validate {
    diagnostics = {diagnostics, 't'},
    bufnr = {bufnr, 'n'},
    client_id = {client_id, 'n', true},
  }

  if not diagnostics then return end

  bufnr = get_bufnr(bufnr)
  client_id = get_client_id(client_id)

  if not _diagnostic_cleanup[bufnr][client_id] then
    _diagnostic_cleanup[bufnr][client_id] = true

    -- Clean up our data when the buffer unloads.
    api.nvim_buf_attach(bufnr, false, {
      on_detach = function(b)
        clear_diagnostic_cache(b, client_id)
        _diagnostic_cleanup[bufnr][client_id] = nil
      end
    })
  end

  set_diagnostic_cache(diagnostics, bufnr, client_id)
end
-- }}}
-- Diagnostic Retrieval {{{


--- Get all diagnostics for all clients
---
---@return {bufnr: Diagnostic[]}
function M.get_all()
  local diagnostics_by_bufnr = {}
  for bufnr, buf_diagnostics in pairs(diagnostic_cache) do
    diagnostics_by_bufnr[bufnr] = {}
    for _, client_diagnostics in pairs(buf_diagnostics) do
      vim.list_extend(diagnostics_by_bufnr[bufnr], client_diagnostics)
    end
  end
  return diagnostics_by_bufnr
end

--- Return associated diagnostics for bufnr
---
---@param bufnr number
---@param client_id number|nil If nil, then return all of the diagnostics.
---                            Else, return just the diagnostics associated with the client_id.
function M.get(bufnr, client_id)
  if client_id == nil then
    local all_diagnostics = {}
    for iter_client_id, _ in pairs(diagnostic_cache[bufnr]) do
      local iter_diagnostics = M.get(bufnr, iter_client_id)

      for _, diagnostic in ipairs(iter_diagnostics) do
        table.insert(all_diagnostics, diagnostic)
      end
    end

    return all_diagnostics
  end

  return diagnostic_cache[bufnr][client_id] or {}
end

--- Get the diagnostics by line
---
---@param bufnr number The buffer number
---@param line_nr number The line number
---@param opts table|nil Configuration keys
---         - severity: (DiagnosticSeverity, default nil)
---             - Only return diagnostics with this severity. Overrides severity_limit
---         - severity_limit: (DiagnosticSeverity, default nil)
---             - Limit severity of diagnostics found. E.g. "Warning" means { "Error", "Warning" } will be valid.
---@param client_id number the client id
---@return table Table with map of line number to list of diagnostics.
--               Structured: { [1] = {...}, [5] = {.... } }
function M.get_line_diagnostics(bufnr, line_nr, opts, client_id)
  opts = opts or {}

  bufnr = bufnr or vim.api.nvim_get_current_buf()
  line_nr = line_nr or vim.api.nvim_win_get_cursor(0)[1] - 1

  local client_get_diags = function(iter_client_id)
    return (diagnostic_cache_lines[bufnr][iter_client_id] or {})[line_nr] or {}
  end

  local line_diagnostics
  if client_id == nil then
    line_diagnostics = {}
    for iter_client_id, _ in pairs(diagnostic_cache_lines[bufnr]) do
      for _, diagnostic in ipairs(client_get_diags(iter_client_id)) do
        table.insert(line_diagnostics, diagnostic)
      end
    end
  else
    line_diagnostics = vim.deepcopy(client_get_diags(client_id))
  end

  if opts.severity then
    line_diagnostics = filter_to_severity_limit(opts.severity, line_diagnostics)
  elseif opts.severity_limit then
    line_diagnostics = filter_by_severity_limit(opts.severity_limit, line_diagnostics)
  end

  if opts.severity_sort then
    table.sort(line_diagnostics, function(a, b) return a.severity < b.severity end)
  end

  return line_diagnostics
end

--- Get the counts for a particular severity
---
--- Useful for showing diagnostic counts in statusline. eg:
---
--- <pre>
--- function! LspStatus() abort
---   let sl = ''
---   if luaeval('not vim.tbl_isempty(vim.lsp.buf_get_clients(0))')
---     let sl.='%#MyStatuslineLSP#E:'
---     let sl.='%#MyStatuslineLSPErrors#%{luaeval("vim.lsp.diagnostic.get_count(0, [[Error]])")}'
---     let sl.='%#MyStatuslineLSP# W:'
---     let sl.='%#MyStatuslineLSPWarnings#%{luaeval("vim.lsp.diagnostic.get_count(0, [[Warning]])")}'
---   else
---       let sl.='%#MyStatuslineLSPErrors#off'
---   endif
---   return sl
--- endfunction
--- let &l:statusline = '%#MyStatuslineLSP#LSP '.LspStatus()
--- </pre>
---
---@param bufnr number The buffer number
---@param severity DiagnosticSeverity
---@param client_id number the client id
function M.get_count(bufnr, severity, client_id)
  if client_id == nil then
    local total = 0
    for iter_client_id, _ in pairs(diagnostic_cache_counts[bufnr]) do
      total = total + M.get_count(bufnr, severity, iter_client_id)
    end

    return total
  end

  return (diagnostic_cache_counts[bufnr][client_id] or {})[DiagnosticSeverity[severity]] or 0
end


-- }}}
-- Diagnostic Movements {{{

--- Helper function to iterate through all of the diagnostic lines
---@return table list of diagnostics
local _iter_diagnostic_lines = function(start, finish, step, bufnr, opts, client_id)
  if bufnr == nil then
    bufnr = vim.api.nvim_get_current_buf()
  end

  local wrap = if_nil(opts.wrap, true)

  local search = function(search_start, search_finish, search_step)
    for line_nr = search_start, search_finish, search_step do
      local line_diagnostics = M.get_line_diagnostics(bufnr, line_nr, opts, client_id)
      if line_diagnostics and not vim.tbl_isempty(line_diagnostics) then
        return line_diagnostics
      end
    end
  end

  local result = search(start, finish, step)

  if wrap then
    local wrap_start, wrap_finish
    if step == 1 then
      wrap_start, wrap_finish = 1, start
    else
      wrap_start, wrap_finish = vim.api.nvim_buf_line_count(bufnr), start
    end

    if not result then
      result = search(wrap_start, wrap_finish, step)
    end
  end

  return result
end

--@private
--- Helper function to ierate through diagnostic lines and return a position
---
---@return table {row, col}
local function _iter_diagnostic_lines_pos(opts, line_diagnostics)
  opts = opts or {}

  local win_id = opts.win_id or vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_win_get_buf(win_id)

  if line_diagnostics == nil or vim.tbl_isempty(line_diagnostics) then
    return false
  end

  local iter_diagnostic = line_diagnostics[1]
  return to_position(iter_diagnostic.range.start, bufnr)
end

--@private
-- Move to the diagnostic position
local function _iter_diagnostic_move_pos(name, opts, pos)
  opts = opts or {}

  local enable_popup = if_nil(opts.enable_popup, true)
  local win_id = opts.win_id or vim.api.nvim_get_current_win()

  if not pos then
    print(string.format("%s: No more valid diagnostics to move to.", name))
    return
  end

  vim.api.nvim_win_set_cursor(win_id, {pos[1] + 1, pos[2]})

  if enable_popup then
    -- This is a bit weird... I'm surprised that we need to wait til the next tick to do this.
    vim.schedule(function()
      M.show_line_diagnostics(opts.popup_opts, vim.api.nvim_win_get_buf(win_id))
    end)
  end
end

--- Get the previous diagnostic closest to the cursor_position
---
---@param opts table See |vim.lsp.diagnostic.goto_next()|
---@return table Previous diagnostic
function M.get_prev(opts)
  opts = opts or {}

  local win_id = opts.win_id or vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_win_get_buf(win_id)
  local cursor_position = opts.cursor_position or vim.api.nvim_win_get_cursor(win_id)

  return _iter_diagnostic_lines(cursor_position[1] - 2, 0, -1, bufnr, opts, opts.client_id)
end

--- Return the pos, {row, col}, for the prev diagnostic in the current buffer.
---@param opts table See |vim.lsp.diagnostic.goto_next()|
---@return table Previous diagnostic position
function M.get_prev_pos(opts)
  return _iter_diagnostic_lines_pos(
    opts,
    M.get_prev(opts)
  )
end

--- Move to the previous diagnostic
---@param opts table See |vim.lsp.diagnostic.goto_next()|
function M.goto_prev(opts)
  return _iter_diagnostic_move_pos(
    "DiagnosticPrevious",
    opts,
    M.get_prev_pos(opts)
  )
end

--- Get the next diagnostic closest to the cursor_position
---@param opts table See |vim.lsp.diagnostic.goto_next()|
---@return table Next diagnostic
function M.get_next(opts)
  opts = opts or {}

  local win_id = opts.win_id or vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_win_get_buf(win_id)
  local cursor_position = opts.cursor_position or vim.api.nvim_win_get_cursor(win_id)

  return _iter_diagnostic_lines(cursor_position[1], vim.api.nvim_buf_line_count(bufnr), 1, bufnr, opts, opts.client_id)
end

--- Return the pos, {row, col}, for the next diagnostic in the current buffer.
---@param opts table See |vim.lsp.diagnostic.goto_next()|
---@return table Next diagnostic position
function M.get_next_pos(opts)
  return _iter_diagnostic_lines_pos(
    opts,
    M.get_next(opts)
  )
end

--- Move to the next diagnostic
---@param opts table|nil Configuration table. Keys:
---         - {client_id}: (number)
---             - If nil, will consider all clients attached to buffer.
---         - {cursor_position}: (Position, default current position)
---             - See |nvim_win_get_cursor()|
---         - {wrap}: (boolean, default true)
---             - Whether to loop around file or not. Similar to 'wrapscan'
---         - {severity}: (DiagnosticSeverity)
---             - Exclusive severity to consider. Overrides {severity_limit}
---         - {severity_limit}: (DiagnosticSeverity)
---             - Limit severity of diagnostics found. E.g. "Warning" means { "Error", "Warning" } will be valid.
---         - {enable_popup}: (boolean, default true)
---             - Call |vim.lsp.diagnostic.show_line_diagnostics()| on jump
---         - {popup_opts}: (table)
---             - Table to pass as {opts} parameter to |vim.lsp.diagnostic.show_line_diagnostics()|
---         - {win_id}: (number, default 0)
---             - Window ID
function M.goto_next(opts)
  return _iter_diagnostic_move_pos(
    "DiagnosticNext",
    opts,
    M.get_next_pos(opts)
  )
end
-- }}}
-- Diagnostic Setters {{{

--- Set signs for given diagnostics
---
--- Sign characters can be customized with the following commands:
---
--- <pre>
--- sign define LspDiagnosticsSignError text=E texthl=LspDiagnosticsSignError linehl= numhl=
--- sign define LspDiagnosticsSignWarning text=W texthl=LspDiagnosticsSignWarning linehl= numhl=
--- sign define LspDiagnosticsSignInformation text=I texthl=LspDiagnosticsSignInformation linehl= numhl=
--- sign define LspDiagnosticsSignHint text=H texthl=LspDiagnosticsSignHint linehl= numhl=
--- </pre>
---@param diagnostics Diagnostic[]
---@param bufnr number The buffer number
---@param client_id number the client id
---@param sign_ns number|nil
---@param opts table Configuration for signs. Keys:
---             - priority: Set the priority of the signs.
---             - severity_limit (DiagnosticSeverity):
---                 - Limit severity of diagnostics found. E.g. "Warning" means { "Error", "Warning" } will be valid.
function M.set_signs(diagnostics, bufnr, client_id, sign_ns, opts)
  opts = opts or {}
  sign_ns = sign_ns or M._get_sign_namespace(client_id)

  if not diagnostics then
    diagnostics = diagnostic_cache[bufnr][client_id]
  end

  if not diagnostics then
    return
  end

  bufnr = get_bufnr(bufnr)
  diagnostics = filter_by_severity_limit(opts.severity_limit, diagnostics)

  local ok = true
  for _, diagnostic in ipairs(diagnostics) do

    ok = ok and pcall(vim.fn.sign_place,
      0,
      sign_ns,
      sign_highlight_map[diagnostic.severity],
      bufnr,
      {
        priority = opts.priority,
        lnum = diagnostic.range.start.line + 1
      }
    )
  end

  if not ok then
    log.debug("Failed to place signs:", diagnostics)
  end
end

--- Set underline for given diagnostics
---
--- Underline highlights can be customized by changing the following |:highlight| groups.
---
--- <pre>
--- LspDiagnosticsUnderlineError
--- LspDiagnosticsUnderlineWarning
--- LspDiagnosticsUnderlineInformation
--- LspDiagnosticsUnderlineHint
--- </pre>
---
---@param diagnostics Diagnostic[]
---@param bufnr number: The buffer number
---@param client_id number: The client id
---@param diagnostic_ns number|nil: The namespace
---@param opts table: Configuration table:
---             - severity_limit (DiagnosticSeverity):
---                 - Limit severity of diagnostics found. E.g. "Warning" means { "Error", "Warning" } will be valid.
function M.set_underline(diagnostics, bufnr, client_id, diagnostic_ns, opts)
  opts = opts or {}

  diagnostic_ns = diagnostic_ns or M._get_diagnostic_namespace(client_id)
  diagnostics = filter_by_severity_limit(opts.severity_limit, diagnostics)

  for _, diagnostic in ipairs(diagnostics) do
    local start = diagnostic.range["start"]
    local finish = diagnostic.range["end"]
    local higroup = underline_highlight_map[diagnostic.severity]

    if higroup == nil then
      -- Default to error if we don't have a highlight associated
      higroup = underline_highlight_map[DiagnosticSeverity.Error]
    end

    highlight.range(
      bufnr,
      diagnostic_ns,
      higroup,
      to_position(start, bufnr),
      to_position(finish, bufnr)
    )
  end
end

-- Virtual Text {{{
--- Set virtual text given diagnostics
---
--- Virtual text highlights can be customized by changing the following |:highlight| groups.
---
--- <pre>
--- LspDiagnosticsVirtualTextError
--- LspDiagnosticsVirtualTextWarning
--- LspDiagnosticsVirtualTextInformation
--- LspDiagnosticsVirtualTextHint
--- </pre>
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
function M.set_virtual_text(diagnostics, bufnr, client_id, diagnostic_ns, opts)
  opts = opts or {}

  client_id = get_client_id(client_id)
  diagnostic_ns = diagnostic_ns or M._get_diagnostic_namespace(client_id)

  local buffer_line_diagnostics
  if diagnostics then
    buffer_line_diagnostics = _diagnostic_lines(diagnostics)
  else
    buffer_line_diagnostics = diagnostic_cache_lines[bufnr][client_id]
  end

  if not buffer_line_diagnostics then
    return nil
  end

  for line, line_diagnostics in pairs(buffer_line_diagnostics) do
    line_diagnostics = filter_by_severity_limit(opts.severity_limit, line_diagnostics)
    local virt_texts = M.get_virtual_text_chunks_for_line(bufnr, line, line_diagnostics, opts)

    if virt_texts then
      api.nvim_buf_set_virtual_text(bufnr, diagnostic_ns, line, virt_texts, {})
    end
  end
end

--- Default function to get text chunks to display using `nvim_buf_set_virtual_text`.
---@param bufnr number The buffer to display the virtual text in
---@param line number The line number to display the virtual text on
---@param line_diags Diagnostic[] The diagnostics associated with the line
---@param opts table See {opts} from |vim.lsp.diagnostic.set_virtual_text()|
---@return table chunks, as defined by |nvim_buf_set_virtual_text()|
function M.get_virtual_text_chunks_for_line(bufnr, line, line_diags, opts)
  assert(bufnr or line)

  if #line_diags == 0 then
    return nil
  end

  opts = opts or {}
  local prefix = opts.prefix or "■"
  local spacing = opts.spacing or 4

  -- Create a little more space between virtual text and contents
  local virt_texts = {{string.rep(" ", spacing)}}

  for i = 1, #line_diags - 1 do
    table.insert(virt_texts, {prefix, virtual_text_highlight_map[line_diags[i].severity]})
  end
  local last = line_diags[#line_diags]

  -- TODO(tjdevries): Allow different servers to be shown first somehow?
  -- TODO(tjdevries): Display server name associated with these?
  if last.message then
    table.insert(
      virt_texts,
      {
        string.format("%s %s", prefix, last.message:gsub("\r", ""):gsub("\n", "  ")),
        virtual_text_highlight_map[last.severity]
      }
    )

    return virt_texts
  end
end
-- }}}
-- }}}
-- Diagnostic Clear {{{
--- Clears the currently displayed diagnostics
---@param bufnr number The buffer number
---@param client_id number the client id
---@param diagnostic_ns number|nil Associated diagnostic namespace
---@param sign_ns number|nil Associated sign namespace
function M.clear(bufnr, client_id, diagnostic_ns, sign_ns)
  validate { bufnr = { bufnr, 'n' } }

  bufnr = (bufnr == 0 and api.nvim_get_current_buf()) or bufnr

  if client_id == nil then
    return vim.lsp.for_each_buffer_client(bufnr, function(_, iter_client_id, _)
      return M.clear(bufnr, iter_client_id)
    end)
  end

  diagnostic_ns = diagnostic_ns or M._get_diagnostic_namespace(client_id)
  sign_ns = sign_ns or M._get_sign_namespace(client_id)

  assert(bufnr, "bufnr is required")
  assert(diagnostic_ns, "Need diagnostic_ns, got nil")
  assert(sign_ns, string.format("Need sign_ns, got nil %s", sign_ns))

  -- clear sign group
  vim.fn.sign_unplace(sign_ns, {buffer=bufnr})

  -- clear virtual text namespace
  api.nvim_buf_clear_namespace(bufnr, diagnostic_ns, 0, -1)
end
-- }}}
-- Diagnostic Insert Leave Handler {{{

--- Callback scheduled for after leaving insert mode
---
--- Used to handle
--@private
function M._execute_scheduled_display(bufnr, client_id)
  local args = _bufs_waiting_to_update[bufnr][client_id]
  if not args then
    return
  end

  -- Clear the args so we don't display unnecessarily.
  _bufs_waiting_to_update[bufnr][client_id] = nil

  M.display(nil, bufnr, client_id, args)
end

local registered = {}

local make_augroup_key = function(bufnr, client_id)
  return string.format("LspDiagnosticInsertLeave:%s:%s", bufnr, client_id)
end

--- Table of autocmd events to fire the update for displaying new diagnostic information
M.insert_leave_auto_cmds = { "InsertLeave", "CursorHoldI" }

--- Used to schedule diagnostic updates upon leaving insert mode.
---
--- For parameter description, see |M.display()|
function M._schedule_display(bufnr, client_id, args)
  _bufs_waiting_to_update[bufnr][client_id] = args

  local key = make_augroup_key(bufnr, client_id)
  if not registered[key] then
    vim.cmd(string.format("augroup %s", key))
    vim.cmd("  au!")
    vim.cmd(
      string.format(
        [[autocmd %s <buffer=%s> :lua vim.lsp.diagnostic._execute_scheduled_display(%s, %s)]],
        table.concat(M.insert_leave_auto_cmds, ","),
        bufnr,
        bufnr,
        client_id
      )
    )
    vim.cmd("augroup END")

    registered[key] = true
  end
end


--- Used in tandem with
---
--- For parameter description, see |M.display()|
function M._clear_scheduled_display(bufnr, client_id)
  local key = make_augroup_key(bufnr, client_id)

  if registered[key] then
    vim.cmd(string.format("augroup %s", key))
    vim.cmd("  au!")
    vim.cmd("augroup END")

    registered[key] = nil
  end
end
-- }}}

-- Diagnostic Private Highlight Utilies {{{
--- Get the severity highlight name
--@private
function M._get_severity_highlight_name(severity)
  return virtual_text_highlight_map[severity]
end

--- Get floating severity highlight name
--@private
function M._get_floating_severity_highlight_name(severity)
  return floating_highlight_map[severity]
end

--- This should be called to update the highlights for the LSP client.
function M._define_default_signs_and_highlights()
  --@private
  local function define_default_sign(name, properties)
    if vim.tbl_isempty(vim.fn.sign_getdefined(name)) then
      vim.fn.sign_define(name, properties)
    end
  end

  -- Initialize default diagnostic highlights
  for severity, hi_info in pairs(diagnostic_severities) do
    local default_highlight_name = default_highlight_map[severity]
    highlight.create(default_highlight_name, hi_info, true)

    -- Default link all corresponding highlights to the default highlight
    highlight.link(virtual_text_highlight_map[severity], default_highlight_name, false)
    highlight.link(floating_highlight_map[severity], default_highlight_name, false)
    highlight.link(sign_highlight_map[severity], default_highlight_name, false)
  end

  -- Create all signs
  for severity, sign_hl_name in pairs(sign_highlight_map) do
    local severity_name = DiagnosticSeverity[severity]

    define_default_sign(sign_hl_name, {
      text = (severity_name or 'U'):sub(1, 1),
      texthl = sign_hl_name,
      linehl = '',
      numhl = '',
    })
  end

  -- Initialize Underline highlights
  for severity, underline_highlight_name in pairs(underline_highlight_map) do
    highlight.create(underline_highlight_name, {
      cterm = 'underline',
      gui   = 'underline',
      guisp = diagnostic_severities[severity].guifg
    }, true)
  end
end
-- }}}
-- Diagnostic Display {{{

--- |lsp-handler| for the method "textDocument/publishDiagnostics"
---
---@note Each of the configuration options accepts:
---         - `false`: Disable this feature
---         - `true`: Enable this feature, use default settings.
---         - `table`: Enable this feature, use overrides.
---         - `function`: Function with signature (bufnr, client_id) that returns any of the above.
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
---     signs = function(bufnr, client_id)
---       return vim.bo[bufnr].show_signs == false
---     end,
---     -- Disable a feature
---     update_in_insert = false,
---   }
--- )
--- </pre>
---
---@param config table Configuration table.
---     - underline:        (default=true)
---         - Apply underlines to diagnostics.
---         - See |vim.lsp.diagnostic.set_underline()|
---     - virtual_text:     (default=true)
---         - Apply virtual text to line endings.
---         - See |vim.lsp.diagnostic.set_virtual_text()|
---     - signs:            (default=true)
---         - Apply signs for diagnostics.
---         - See |vim.lsp.diagnostic.set_signs()|
---     - update_in_insert: (default=false)
---         - Update diagnostics in InsertMode or wait until InsertLeave
function M.on_publish_diagnostics(_, _, params, client_id, _, config)
  local uri = params.uri
  local bufnr = vim.uri_to_bufnr(uri)

  if not bufnr then
    return
  end

  local diagnostics = params.diagnostics

  -- Always save the diagnostics, even if the buf is not loaded.
  -- Language servers may report compile or build errors via diagnostics
  -- Users should be able to find these, even if they're in files which
  -- are not loaded.
  M.save(diagnostics, bufnr, client_id)

  -- Unloaded buffers should not handle diagnostics.
  --    When the buffer is loaded, we'll call on_attach, which sends textDocument/didOpen.
  --    This should trigger another publish of the diagnostics.
  --
  -- In particular, this stops a ton of spam when first starting a server for current
  -- unloaded buffers.
  if not api.nvim_buf_is_loaded(bufnr) then
    return
  end

  M.display(diagnostics, bufnr, client_id, config)
end

--@private
--- Display diagnostics for the buffer, given a configuration.
function M.display(diagnostics, bufnr, client_id, config)
  config = vim.lsp._with_extend('vim.lsp.diagnostic.on_publish_diagnostics', {
    signs = true,
    underline = true,
    virtual_text = true,
    update_in_insert = false,
  }, config)

  -- TODO(tjdevries): Consider how we can make this a "standardized" kind of thing for |lsp-handlers|.
  --    It seems like we would probably want to do this more often as we expose more of them.
  --    It provides a very nice functional interface for people to override configuration.
  local resolve_optional_value = function(option)
    local enabled_val = {}

    if not option then
      return false
    elseif option == true then
      return enabled_val
    elseif type(option) == 'function' then
      local val = option(bufnr, client_id)
      if val == true then
        return enabled_val
      else
        return val
      end
    elseif type(option) == 'table' then
      return option
    else
      error("Unexpected option type: " .. vim.inspect(option))
    end
  end

  if resolve_optional_value(config.update_in_insert) then
    M._clear_scheduled_display(bufnr, client_id)
  else
    local mode = vim.api.nvim_get_mode()

    if string.sub(mode.mode, 1, 1) == 'i' then
      M._schedule_display(bufnr, client_id, config)
      return
    end
  end

  M.clear(bufnr, client_id)

  diagnostics = diagnostics or M.get(bufnr, client_id)

  vim.api.nvim_command("doautocmd <nomodeline> User LspDiagnosticsChanged")

  if not diagnostics or vim.tbl_isempty(diagnostics) then
    return
  end

  local underline_opts = resolve_optional_value(config.underline)
  if underline_opts then
    M.set_underline(diagnostics, bufnr, client_id, nil, underline_opts)
  end

  local virtual_text_opts = resolve_optional_value(config.virtual_text)
  if virtual_text_opts then
    M.set_virtual_text(diagnostics, bufnr, client_id, nil, virtual_text_opts)
  end

  local signs_opts = resolve_optional_value(config.signs)
  if signs_opts then
    M.set_signs(diagnostics, bufnr, client_id, nil, signs_opts)
  end
end
-- }}}
-- Diagnostic User Functions {{{

--- Open a floating window with the diagnostics from {line_nr}
---
--- The floating window can be customized with the following highlight groups:
--- <pre>
--- LspDiagnosticsFloatingError
--- LspDiagnosticsFloatingWarning
--- LspDiagnosticsFloatingInformation
--- LspDiagnosticsFloatingHint
--- </pre>
---@param opts table Configuration table
---     - show_header (boolean, default true): Show "Diagnostics:" header.
---@param bufnr number The buffer number
---@param line_nr number The line number
---@param client_id number|nil the client id
---@return table {popup_bufnr, win_id}
function M.show_line_diagnostics(opts, bufnr, line_nr, client_id)
  opts = opts or {}
  opts.severity_sort = if_nil(opts.severity_sort, true)

  local show_header = if_nil(opts.show_header, true)

  bufnr = bufnr or 0
  line_nr = line_nr or (vim.api.nvim_win_get_cursor(0)[1] - 1)

  local lines = {}
  local highlights = {}
  if show_header then
    table.insert(lines, "Diagnostics:")
    table.insert(highlights, {0, "Bold"})
  end

  local line_diagnostics = M.get_line_diagnostics(bufnr, line_nr, opts, client_id)
  if vim.tbl_isempty(line_diagnostics) then return end

  for i, diagnostic in ipairs(line_diagnostics) do
    local prefix = string.format("%d. ", i)
    local hiname = M._get_floating_severity_highlight_name(diagnostic.severity)
    assert(hiname, 'unknown severity: ' .. tostring(diagnostic.severity))

    local message_lines = vim.split(diagnostic.message, '\n', true)
    table.insert(lines, prefix..message_lines[1])
    table.insert(highlights, {#prefix + 1, hiname})
    for j = 2, #message_lines do
      table.insert(lines, message_lines[j])
      table.insert(highlights, {0, hiname})
    end
  end

  local popup_bufnr, winnr = util.open_floating_preview(lines, 'plaintext')
  for i, hi in ipairs(highlights) do
    local prefixlen, hiname = unpack(hi)
    -- Start highlight after the prefix
    api.nvim_buf_add_highlight(popup_bufnr, -1, hiname, i-1, prefixlen, -1)
  end

  return popup_bufnr, winnr
end

local loclist_type_map = {
  [DiagnosticSeverity.Error] = 'E',
  [DiagnosticSeverity.Warning] = 'W',
  [DiagnosticSeverity.Information] = 'I',
  [DiagnosticSeverity.Hint] = 'I',
}


--- Clear diagnotics and diagnostic cache
---
--- Handles saving diagnostics from multiple clients in the same buffer.
---@param client_id number
---@param buffer_client_map table map of buffers to active clients
function M.reset(client_id, buffer_client_map)
  buffer_client_map = vim.deepcopy(buffer_client_map)
  vim.schedule(function()
    for bufnr, client_ids in pairs(buffer_client_map) do
      if client_ids[client_id] then
        clear_diagnostic_cache(bufnr, client_id)
        M.clear(bufnr, client_id)
      end
    end
  end)
end

--- Sets the location list
---@param opts table|nil Configuration table. Keys:
---         - {open_loclist}: (boolean, default true)
---             - Open loclist after set
---         - {client_id}: (number)
---             - If nil, will consider all clients attached to buffer.
---         - {severity}: (DiagnosticSeverity)
---             - Exclusive severity to consider. Overrides {severity_limit}
---         - {severity_limit}: (DiagnosticSeverity)
---             - Limit severity of diagnostics found. E.g. "Warning" means { "Error", "Warning" } will be valid.
function M.set_loclist(opts)
  opts = opts or {}

  local open_loclist = if_nil(opts.open_loclist, true)

  local bufnr = vim.api.nvim_get_current_buf()
  local buffer_diags = M.get(bufnr, opts.client_id)

  if opts.severity then
    buffer_diags = filter_to_severity_limit(opts.severity, buffer_diags)
  elseif opts.severity_limit then
    buffer_diags = filter_by_severity_limit(opts.severity_limit, buffer_diags)
  end

  local items = {}
  local insert_diag = function(diag)
    local pos = diag.range.start
    local row = pos.line
    local col = util.character_offset(bufnr, row, pos.character)

    local line = (api.nvim_buf_get_lines(bufnr, row, row + 1, false) or {""})[1]

    table.insert(items, {
      bufnr = bufnr,
      lnum = row + 1,
      col = col + 1,
      text = line .. " | " .. diag.message,
      type = loclist_type_map[diag.severity or DiagnosticSeverity.Error] or 'E',
    })
  end

  for _, diag in ipairs(buffer_diags) do
    insert_diag(diag)
  end

  table.sort(items, function(a, b) return a.lnum < b.lnum end)

  util.set_loclist(items)
  if open_loclist then
    vim.cmd [[lopen]]
  end
end
-- }}}

return M
