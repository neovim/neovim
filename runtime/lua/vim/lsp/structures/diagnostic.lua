local api = vim.api
local validate = vim.validate

local log = require('vim.lsp.log')
local highlight = require('vim.highlight')
local protocol = require('vim.lsp.protocol')
local util = require('vim.lsp.util')

local Position = require('vim.lsp.structures.position')

--- Diagnostics received from the server via `textDocument/publishDiagnostics`
--
--  {<bufnr>: {diagnostics}}
--
-- This contains only entries for active buffers. Entries for detached buffers
-- are discarded.
--
-- If you override the `textDocument/publishDiagnostic` callback,
-- this will be empty unless you call `buf_diagnostics_save_positions`.
--
--
-- Diagnostic is:
--
-- {
--    range: Range
--    message: string
--    severity?: DiagnosticSeverity
--    code?: number | string
--    source?: string
--    tags?: DiagnosticTag[]
--    relatedInformation?: DiagnosticRelatedInformation[]
-- }
local Diagnostic = {}

local underline_highlight_name = "LspDiagnosticsUnderline"

Diagnostic.config = util.generate_config({
  underline_highlight_map = {
    {
      [protocol.DiagnosticSeverity.Error]       = underline_highlight_name .. 'Error',
      [protocol.DiagnosticSeverity.Warning]     = underline_highlight_name .. 'Warning',
      [protocol.DiagnosticSeverity.Information] = underline_highlight_name .. 'Information',
      [protocol.DiagnosticSeverity.Hint]        = underline_highlight_name .. 'Hint',
    },
    't',
  },

  sign_severity_map = {
    {
      [protocol.DiagnosticSeverity.Error]       = "LspDiagnosticsErrorSign";
      [protocol.DiagnosticSeverity.Warning]     = "LspDiagnosticsWarningSign";
      [protocol.DiagnosticSeverity.Information] = "LspDiagnosticsInformationSign";
      [protocol.DiagnosticSeverity.Hint]        = "LspDiagnosticsHintSign";
    },
    't',
  },

  highlight_severity_map = {
    {
      [protocol.DiagnosticSeverity.Error] = { guifg = "Red" };
      [protocol.DiagnosticSeverity.Warning] = { guifg = "Orange" };
      [protocol.DiagnosticSeverity.Information] = { guifg = "LightBlue" };
      [protocol.DiagnosticSeverity.Hint] = { guifg = "LightGrey" };
    },
    't'
  },
})

local severity_highlights = {}
local floating_severity_highlights = {}

local DEFAULT_CLIENT_ID = -1
local get_client_id = function(client_id)
  if client_id == nil then
    client_id = DEFAULT_CLIENT_ID
  end

  return client_id
end

local _diagnostic_namespaces = setmetatable({[DEFAULT_CLIENT_ID] = api.nvim_create_namespace("vim_lsp_diagnostics")}, {
  __index = function(t, client_id)
    client_id = get_client_id(client_id)

    if rawget(t, client_id) == nil then
      rawset(t, client_id, api.nvim_create_namespace(string.format("vim_lsp_diagnostics:%s", client_id)))
    end

    return rawget(t, client_id)
  end
})

local _sign_namespaces = setmetatable({[DEFAULT_CLIENT_ID] = "vim_lsp_signs"}, {
  __index = function(t, client_id)
    client_id = get_client_id(client_id)

    if rawget(t, client_id) == nil then
      rawset(t, client_id, string.format("vim_lsp_signs:%s", client_id))
    end

    return rawget(t, client_id)
  end
})


local bufnr_and_client_cacher_mt = {
  __index = function(t, bufnr)
    if bufnr == 0 or bufnr == nil then
      bufnr = vim.api.nvim_get_current_buf()
    end

    local existing = rawget(t, bufnr)
    if existing then
      return existing
    end

    rawset(t, bufnr, {})
    return t[bufnr]
  end,

  __newindex = function(t, bufnr, v)
    if bufnr == 0 or bufnr == nil then
      bufnr = vim.api.nvim_get_current_buf()
    end

    t[bufnr] = v
  end,
}

local diagnostic_cache = setmetatable({}, bufnr_and_client_cacher_mt)
local diagnostic_cache_lines = setmetatable({}, bufnr_and_client_cacher_mt)
local diagnostic_cache_counts = setmetatable({}, bufnr_and_client_cacher_mt)

local _bufs_waiting_to_update = setmetatable({}, bufnr_and_client_cacher_mt)


Diagnostic.underline = function(diagnostics, bufnr, client_id, diagnostic_ns)
  diagnostic_ns = diagnostic_ns or Diagnostic._get_diagnostic_namespace(client_id)

  for _, diagnostic in ipairs(diagnostics) do
    local start = diagnostic.range["start"]
    local finish = diagnostic.range["end"]

    highlight.range(
      bufnr,
      diagnostic_ns,
      Diagnostic.config.underline_highlight_map[diagnostic.severity],
      Position.to_pos(start, bufnr),
      Position.to_pos(finish, bufnr)
    )
  end
end

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

local _diagnostic_counts = function(diagnostics)
  if not diagnostics then return end

  local counts = {}
  for _, diagnostic in pairs(diagnostics) do
    if diagnostic.severity then
      if counts[diagnostic.severity] == nil then
        counts[diagnostic.severity] = 0
      end

      counts[diagnostic.severity] = counts[diagnostic.severity] + 1
    end
  end

  return counts
end

local set_diagnostic_cache = function(diagnostics, bufnr, client_id)
  client_id = get_client_id(client_id)

  -- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#diagnostic
  --
  -- The diagnostic's severity. Can be omitted. If omitted it is up to the
  -- client to interpret diagnostics as error, warning, info or hint.
  -- TODO: Replace this with server-specific heuristics to infer severity.
  for _, diagnostic in ipairs(diagnostics) do
    if diagnostic.severity == nil then
      diagnostic.severity = protocol.DiagnosticSeverity.Error
    end
  end

  diagnostic_cache[bufnr][client_id] = diagnostics
  diagnostic_cache_lines[bufnr][client_id] = _diagnostic_lines(diagnostics)
  diagnostic_cache_counts[bufnr][client_id] = _diagnostic_counts(diagnostics)
end

local clear_diagnostic_cache = function(bufnr, client_id)
  client_id = get_client_id(client_id)

  diagnostic_cache[bufnr][client_id] = nil
  diagnostic_cache_lines[bufnr][client_id] = nil
  diagnostic_cache_counts[bufnr][client_id] = nil
end

Diagnostic.save_buf_diagnostics = function(diagnostics, bufnr, client_id)
  validate {
    diagnostics = {diagnostics, 't'},
    bufnr = {bufnr, 'n'},
    client_id = {client_id, 'n', true},
  }

  if not diagnostics then return end
  bufnr = bufnr == 0 and api.nvim_get_current_buf() or bufnr

  if not diagnostic_cache[bufnr][client_id] then
    -- Clean up our data when the buffer unloads.
    api.nvim_buf_attach(bufnr, false, {
      on_detach = function(b)
        clear_diagnostic_cache(b, client_id)
      end
    })
  end

  set_diagnostic_cache(diagnostics, bufnr, client_id)
end

Diagnostic.set_virtual_text = function(diagnostics, bufnr, client_id, diagnostic_ns)
  if not diagnostics then
    return
  end

  client_id = get_client_id(client_id)

  diagnostic_ns = diagnostic_ns or Diagnostic._get_diagnostic_namespace(client_id)

  -- TODO: Needs to get all the lines for DEFAULT_CLIENT_ID...
  local buffer_line_diagnostics = diagnostic_cache_lines[bufnr][client_id] or _diagnostic_lines(diagnostics)

  for line, line_diagnostics in pairs(buffer_line_diagnostics) do
    local virt_texts = {}
    for i = 1, #line_diagnostics - 1 do
      table.insert(virt_texts, {"■", severity_highlights[line_diagnostics[i].severity]})
    end
    local last = line_diagnostics[#line_diagnostics]
    -- TODO(ashkan) use first line instead of subbing 2 spaces?

    -- TODO(tjdevries): Should use highest severity message here.
    -- TODO(tjdevries): Allow different severs to be shown first somehow?
    if last.message then
      table.insert(
        virt_texts,
        {
          string.format("■ %s", last.message:gsub("\r", ""):gsub("\n", "  ")),
          severity_highlights[last.severity]
        }
      )
      api.nvim_buf_set_virtual_text(bufnr, diagnostic_ns, line, virt_texts, {})
    end
  end
end

Diagnostic.get_buf_diagnostics = function(bufnr, client_id)
  if client_id == nil then
    local all_diagnostics = {}
    for iter_client_id, _ in pairs(diagnostic_cache[bufnr]) do
      local iter_diagnostics = Diagnostic.get_buf_diagnostics(bufnr, iter_client_id)

      for _, diagnostic in ipairs(iter_diagnostics) do
        table.insert(all_diagnostics, diagnostic)
      end
    end

    return all_diagnostics
  end

  return diagnostic_cache[bufnr][client_id]
end

-- TODO: I don't like that this function is "special" in that doesn't take any diagnostics as first arg.
-- TODO: Rename to something like Diagnostic.get_saved_counts or similar
Diagnostic.get_counts = function(bufnr, kind, client_id)
  if client_id == nil then
    local total = 0
    for iter_client_id, _ in pairs(diagnostic_cache_counts[bufnr]) do
      total = total + Diagnostic.get_counts(bufnr, kind, iter_client_id)
    end

    return total
  end

  return ((diagnostic_cache_counts[bufnr][client_id] or {})[protocol.DiagnosticSeverity[kind]] or 0)
end

Diagnostic.get_line_diagnostics = function(bufnr, line_nr, client_id)
  if client_id == nil then
    local line_diagnostics = {}
    for iter_client_id, _ in pairs(diagnostic_cache_lines[bufnr]) do
      local iter_diagnostics = Diagnostic.get_line_diagnostics(bufnr, line_nr, iter_client_id)
      for _, diagnostic in ipairs(iter_diagnostics) do
        table.insert(line_diagnostics, diagnostic)
      end
    end

    return line_diagnostics
  end

  return ((diagnostic_cache_lines[bufnr][client_id] or {})[line_nr] or {})
end


-- TODO(tjdevries): Do the same stuff w/ client_id I did elsewhere.
Diagnostic.set_signs = function(diagnostics, bufnr, client_id, sign_ns)
  sign_ns = sign_ns or Diagnostic._get_sign_namespace(client_id)

  for _, diagnostic in ipairs(diagnostics) do
    vim.fn.sign_place(
      0,
      sign_ns,
      Diagnostic.config.sign_severity_map[diagnostic.severity],
      bufnr,
      { lnum = diagnostic.range.start.line + 1 }
    )
  end
end

Diagnostic.buf_clear_displayed_diagnostics = function(bufnr, client_id, diagnostic_ns, sign_ns)
  validate { bufnr = { bufnr, 'n' } }

  bufnr = (bufnr == 0 and api.nvim_get_current_buf()) or bufnr
  diagnostic_ns = diagnostic_ns or Diagnostic._get_diagnostic_namespace(client_id)
  sign_ns = sign_ns or Diagnostic._get_sign_namespace(client_id)

  -- clear sign group
  vim.fn.sign_unplace(sign_ns, {buffer=bufnr})

  -- clear virtual text namespace
  api.nvim_buf_clear_namespace(bufnr, diagnostic_ns, 0, -1)
end


Diagnostic.display = function(diagnostics, bufnr, client_id, args)
  args = vim.tbl_extend("force", {
    should_underline = true,
    update_in_insert = true,
  }, args or {})

  -- util.buf_clear_diagnostics(bufnr)
  -- TODO: Decide if this is actually what we want to call this.
  Diagnostic.buf_clear_displayed_diagnostics(bufnr, client_id)

  diagnostics = diagnostics or diagnostic_cache[bufnr][client_id]

  log.debug("Calling display...", vim.inspect(vim.v.event), bufnr, client_id, vim.inspect(args), vim.inspect(diagnostics))

  if not diagnostics or vim.tbl_isempty(diagnostics) then
    return
  end

  if args.should_underline then
    Diagnostic.underline(diagnostics, bufnr, client_id)
  end

  -- util.buf_diagnostics_virtual_text(bufnr, notification.diagnostics)
  Diagnostic.set_virtual_text(diagnostics, bufnr, client_id)

  -- util.buf_diagnostics_signs(bufnr, notification.diagnostics)
  Diagnostic.set_signs(diagnostics, bufnr, client_id)

  vim.api.nvim_command("doautocmd User LspDiagnosticsChanged")
end

Diagnostic._buf_on_insert_leave = function(bufnr, client_id)
  local args = table.remove(_bufs_waiting_to_update[bufnr], client_id)

  Diagnostic.display(nil, bufnr, client_id, args)
end

local registered = {}

Diagnostic.buf_schedule_display_on_insert_leave = function(bufnr, client_id, args)
  if _bufs_waiting_to_update[bufnr][client_id] then
    return
  end

  _bufs_waiting_to_update[bufnr][client_id] = args

  local key = string.format("%s:%s", bufnr, client_id)
  if not registered[key] then
    vim.cmd(
      string.format(
        -- TODO: Should really think about these more or make it configurable.
        [[autocmd InsertLeave,CursorHoldI <buffer=%s> :lua require("vim.lsp.structures").Diagnostic._buf_on_insert_leave(%s, %s)]],
        bufnr,
        bufnr,
        client_id
      )
    )

    registered[key] = true
  end
end

Diagnostic._get_diagnostic_namespace = function(client_id)
  return _diagnostic_namespaces[client_id]
end

Diagnostic._get_sign_namespace = function(client_id)
  return _sign_namespaces[client_id]
end

Diagnostic._get_severity_highlight_name = function(severity)
  return severity_highlights[severity]
end
Diagnostic._get_floating_severity_highlight_name = function(severity)
  return floating_severity_highlights[severity]
end

Diagnostic._define_default_signs_and_highlights = function()
  local function define_default_sign(name, properties)
    if vim.tbl_isempty(vim.fn.sign_getdefined(name)) then
      vim.fn.sign_define(name, properties)
    end
  end

  define_default_sign('LspDiagnosticsErrorSign', {text='E', texthl='LspDiagnosticsErrorSign', linehl='', numhl=''})
  define_default_sign('LspDiagnosticsWarningSign', {text='W', texthl='LspDiagnosticsWarningSign', linehl='', numhl=''})
  define_default_sign('LspDiagnosticsInformationSign', {text='I', texthl='LspDiagnosticsInformationSign', linehl='', numhl=''})
  define_default_sign('LspDiagnosticsHintSign', {text='H', texthl='LspDiagnosticsHintSign', linehl='', numhl=''})

  -- Initialize default severity highlights
  for severity, hi_info in pairs(Diagnostic.config.highlight_severity_map) do
    local severity_name = protocol.DiagnosticSeverity[severity]
    local highlight_name = "LspDiagnostics"..severity_name
    local floating_highlight_name = highlight_name.."Floating"

    highlight.create(highlight_name, hi_info, true)
    highlight.link(highlight_name .. 'Sign', highlight_name)
    highlight.link(highlight_name .. 'Floating', highlight_name)

    severity_highlights[severity] = highlight_name
    floating_severity_highlights[severity] = floating_highlight_name
  end

  -- Initialize Underline highlights
  -- TODO(tjdevries): Figure out whether this is the right loop here...
  vim.cmd(string.format("highlight default %s gui=underline cterm=underline", underline_highlight_name))
  for kind, _ in pairs(protocol.DiagnosticSeverity) do
    if type(kind) == 'string' then
      vim.cmd(string.format("highlight default link %s%s %s", underline_highlight_name, kind, underline_highlight_name))
    end
  end
end

return Diagnostic
