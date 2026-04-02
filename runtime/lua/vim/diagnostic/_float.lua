local api, if_nil = vim.api, vim.F.if_nil
local shared = require('vim.diagnostic._shared')
local store = require('vim.diagnostic._store')

--- @class (private) vim.diagnostic._float
local M = {}

local severity = vim.diagnostic.severity

--- @type table<vim.diagnostic.Severity, string>
local floating_highlight_map = {
  [severity.ERROR] = 'DiagnosticFloatingError',
  [severity.WARN] = 'DiagnosticFloatingWarn',
  [severity.INFO] = 'DiagnosticFloatingInfo',
  [severity.HINT] = 'DiagnosticFloatingHint',
}

--- @param opts vim.diagnostic.Opts.Float
--- @param bufnr integer
--- @return vim.diagnostic.Opts.Float, vim.diagnostic.Opts
local function resolve_float_opts(opts, bufnr)
  -- Resolve options with user settings from vim.diagnostic.config
  -- Unlike the other decoration functions (e.g. set_virtual_text, set_signs, etc.) `open_float`
  -- does not have a dedicated table for configuration options; instead, the options are mixed in
  -- with its `opts` table. We create a dedicated options table (`float_opts`) that inherits
  -- missing keys from the global configuration (`global_diagnostic_options.float`), which can
  -- be a table or a function.
  local global_opts = assert(vim.diagnostic.config())
  local float_opts = global_opts.float
  local resolved_float_opts = type(float_opts) == 'table' and float_opts
    or (type(float_opts) == 'function' and float_opts(opts.namespace, bufnr) or {})

  return vim.tbl_extend('keep', opts, resolved_float_opts), global_opts
end

--- @param opts vim.diagnostic.Opts.Float?
--- @return integer? float_bufnr
--- @return integer? winid
function M.open(opts, ...)
  -- Support old (bufnr, opts) signature
  local bufnr --- @type integer?
  if opts == nil or type(opts) == 'number' then
    bufnr = opts
    opts = ... --- @type vim.diagnostic.Opts.Float
  else
    vim.validate('opts', opts, 'table', true)
  end

  opts = opts or {}
  bufnr = vim._resolve_bufnr(bufnr or opts.bufnr)
  local global_opts --- @type vim.diagnostic.Opts
  opts, global_opts = resolve_float_opts(opts, bufnr)

  local scope = ({ l = 'line', c = 'cursor', b = 'buffer' })[opts.scope] or opts.scope or 'line'
  local lnum, col --- @type integer, integer
  local opts_pos = opts.pos
  if scope == 'line' or scope == 'cursor' then
    if not opts_pos then
      local pos = api.nvim_win_get_cursor(0)
      lnum = pos[1] - 1
      col = pos[2]
    elseif type(opts_pos) == 'number' then
      lnum = opts_pos
    elseif type(opts_pos) == 'table' then
      lnum, col = opts_pos[1], opts_pos[2]
    else
      error("Invalid value for option 'pos'")
    end
  elseif scope ~= 'buffer' then
    error("Invalid value for option 'scope'")
  end

  local diagnostics = store.get_diagnostics(bufnr, opts --[[@as vim.diagnostic.GetOpts]], true)

  if scope == 'line' then
    --- @param diagnostic vim.Diagnostic
    local function line_filter(diagnostic)
      local d_lnum, _, d_end_lnum, d_end_col = shared.get_logical_pos(diagnostic)
      return lnum >= d_lnum
        and lnum <= d_end_lnum
        and (d_lnum == d_end_lnum or lnum ~= d_end_lnum or d_end_col ~= 0)
    end
    diagnostics = vim.tbl_filter(line_filter, diagnostics)
  elseif scope == 'cursor' then
    -- If `col` is past the end of the line, show if the cursor is on the last char in the line
    local line_length = #api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, true)[1]
    --- @param diagnostic vim.Diagnostic
    local function cursor_filter(diagnostic)
      local d_lnum, d_col, d_end_lnum, d_end_col = shared.get_logical_pos(diagnostic)
      return lnum >= d_lnum
        and lnum <= d_end_lnum
        and (lnum ~= d_lnum or col >= math.min(d_col, line_length - 1))
        and ((d_lnum == d_end_lnum and d_col == d_end_col) or lnum ~= d_end_lnum or col < d_end_col)
    end
    diagnostics = vim.tbl_filter(cursor_filter, diagnostics)
  end

  if vim.tbl_isempty(diagnostics) then
    return
  end

  local severity_sort = if_nil(opts.severity_sort, global_opts.severity_sort)
  if severity_sort then
    if type(severity_sort) == 'table' and severity_sort.reverse then
      table.sort(diagnostics, function(a, b)
        return shared.diagnostic_cmp(a, b, 'severity', true)
      end)
    else
      table.sort(diagnostics, function(a, b)
        return shared.diagnostic_cmp(a, b, 'severity', false)
      end)
    end
  end

  local lines = {} --- @type string[]
  local highlights = {} --- @type { hlname: string, prefix?: { length: integer, hlname: string? }, suffix?: { length: integer, hlname: string? } }[]
  local header = if_nil(opts.header, 'Diagnostics:')
  if header then
    vim.validate('header', header, { 'string', 'table' }, "'string' or 'table'")
    if type(header) == 'table' then
      -- Don't insert any lines for an empty string
      if #(header[1] or '') > 0 then
        lines[#lines + 1] = header[1]
        highlights[#highlights + 1] = { hlname = header[2] or 'Bold' }
      end
    elseif #header > 0 then
      lines[#lines + 1] = header
      highlights[#highlights + 1] = { hlname = 'Bold' }
    end
  end

  if opts.format then
    diagnostics = shared.reformat_diagnostics(opts.format, diagnostics)
  end

  if opts.source and (opts.source ~= 'if_many' or shared.count_sources(bufnr) > 1) then
    diagnostics = shared.prefix_source(diagnostics)
  end

  local prefix_opt = opts.prefix
    or (scope == 'cursor' and #diagnostics <= 1) and ''
    or function(_, i)
      return string.format('%d. ', i)
    end

  local prefix, prefix_hl_group --- @type string?, string?
  if prefix_opt then
    vim.validate(
      'prefix',
      prefix_opt,
      { 'string', 'table', 'function' },
      "'string' or 'table' or 'function'"
    )
    if type(prefix_opt) == 'string' then
      prefix, prefix_hl_group = prefix_opt, 'NormalFloat'
    elseif type(prefix_opt) == 'table' then
      prefix, prefix_hl_group = prefix_opt[1] or '', prefix_opt[2] or 'NormalFloat'
    end
  end

  local suffix_opt = opts.suffix
    or function(diagnostic)
      return diagnostic.code and string.format(' [%s]', diagnostic.code) or ''
    end

  local suffix, suffix_hl_group --- @type string?, string?
  if suffix_opt then
    vim.validate(
      'suffix',
      suffix_opt,
      { 'string', 'table', 'function' },
      "'string' or 'table' or 'function'"
    )
    if type(suffix_opt) == 'string' then
      suffix, suffix_hl_group = suffix_opt, 'NormalFloat'
    elseif type(suffix_opt) == 'table' then
      suffix, suffix_hl_group = suffix_opt[1] or '', suffix_opt[2] or 'NormalFloat'
    end
  end

  local related_info_locations = {} --- @type table<integer, lsp.Location>
  for i, diagnostic in ipairs(diagnostics) do
    if type(prefix_opt) == 'function' then
      local prefix0, prefix_hl_group0 = prefix_opt(diagnostic, i, #diagnostics)
      prefix, prefix_hl_group = prefix0 or '', prefix_hl_group0 or 'NormalFloat'
    end
    if type(suffix_opt) == 'function' then
      local suffix0, suffix_hl_group0 = suffix_opt(diagnostic, i, #diagnostics)
      suffix, suffix_hl_group = suffix0 or '', suffix_hl_group0 or 'NormalFloat'
    end

    local hiname = floating_highlight_map[diagnostic.severity]
    local message_lines = vim.split(diagnostic.message, '\n')
    local default_pre = string.rep(' ', #prefix)
    for j = 1, #message_lines do
      local pre = j == 1 and prefix or default_pre
      local suf = j == #message_lines and suffix or ''
      lines[#lines + 1] = pre .. message_lines[j] .. suf
      highlights[#highlights + 1] = {
        hlname = hiname,
        prefix = {
          length = j == 1 and #prefix or 0,
          hlname = prefix_hl_group,
        },
        suffix = {
          length = #suf,
          hlname = suffix_hl_group,
        },
      }
    end

    --- @type lsp.DiagnosticRelatedInformation[]
    local related_info = vim.tbl_get(diagnostic, 'user_data', 'lsp', 'relatedInformation') or {}
    -- Below the diagnostic, show its LSP related information (if any) in the form of file name and
    -- range, plus description.
    for _, info in ipairs(related_info) do
      local location = info.location
      local file_name = vim.fs.basename(vim.uri_to_fname(location.uri))
      local info_suffix = ': ' .. info.message
      related_info_locations[#lines + 1] = location
      lines[#lines + 1] = string.format(
        '%s%s:%s:%s%s',
        default_pre,
        file_name,
        location.range.start.line + 1,
        location.range.start.character + 1,
        info_suffix
      )
      highlights[#highlights + 1] = {
        hlname = '@string.special.path',
        prefix = {
          length = #default_pre,
          hlname = prefix_hl_group,
        },
        suffix = {
          length = #info_suffix,
          hlname = 'NormalFloat',
        },
      }
    end
  end

  -- Used by open_floating_preview to allow the float to be focused
  if not opts.focus_id then
    opts.focus_id = scope
  end

  --- @diagnostic disable-next-line: param-type-mismatch
  local float_bufnr, winnr = vim.lsp.util.open_floating_preview(lines, 'plaintext', opts)
  vim.bo[float_bufnr].path = vim.bo[bufnr].path

  -- TODO: Handle this generally (like vim.ui.open()), rather than overriding gf.
  vim.keymap.set('n', 'gf', function()
    local cursor_row = api.nvim_win_get_cursor(0)[1]
    local location = related_info_locations[cursor_row]
    if location then
      -- Split the window before calling `show_document` so the window doesn't disappear.
      vim.cmd.split()
      vim.lsp.util.show_document(location, 'utf-16', { focus = true })
    else
      vim.cmd.normal({ 'gf', bang = true })
    end
  end, { buf = float_bufnr, remap = false })

  --- @diagnostic disable-next-line: deprecated
  local add_highlight = api.nvim_buf_add_highlight

  for i, hl in ipairs(highlights) do
    local line = lines[i]
    local prefix_len = hl.prefix and hl.prefix.length or 0
    local suffix_len = hl.suffix and hl.suffix.length or 0
    if prefix_len > 0 then
      add_highlight(float_bufnr, -1, hl.prefix.hlname, i - 1, 0, prefix_len)
    end
    add_highlight(float_bufnr, -1, hl.hlname, i - 1, prefix_len, #line - suffix_len)
    if suffix_len > 0 then
      add_highlight(float_bufnr, -1, hl.suffix.hlname, i - 1, #line - suffix_len, -1)
    end
  end

  return float_bufnr, winnr
end

return M
