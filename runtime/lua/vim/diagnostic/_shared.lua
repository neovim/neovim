local api = vim.api

local store = require('vim.diagnostic._store')

--- @class (private) vim.diagnostic._shared
local M = {}

--- @param bufnr integer
--- @return integer
function M.count_sources(bufnr)
  local count = 0
  local seen = {} --- @type table<string, true>
  for _, diagnostic in ipairs(store.get_diagnostics(bufnr, nil, false)) do
    local source = diagnostic.source
    if source and not seen[source] then
      seen[source] = true
      count = count + 1
    end
  end
  return count
end

--- @param diagnostics vim.Diagnostic[]
--- @return vim.Diagnostic[]
function M.prefix_source(diagnostics)
  --- @param diagnostic vim.Diagnostic
  return vim.tbl_map(function(diagnostic)
    if not diagnostic.source then
      return diagnostic
    end

    local copied = vim.deepcopy(diagnostic, true)
    copied.message = string.format('%s: %s', diagnostic.source, diagnostic.message)
    return copied
  end, diagnostics)
end

--- Get a position based on an extmark referenced by `_extmark_id` field
--- @param diagnostic vim.Diagnostic
--- @return integer lnum
--- @return integer col
--- @return integer end_lnum
--- @return integer end_col
--- @return boolean valid
function M.get_logical_pos(diagnostic)
  if not diagnostic._extmark_id then
    return diagnostic.lnum, diagnostic.col, diagnostic.end_lnum, diagnostic.end_col, true
  end

  local ns = vim.diagnostic.get_namespace(diagnostic.namespace)
  local extmark = api.nvim_buf_get_extmark_by_id(
    diagnostic.bufnr,
    ns.user_data.location_ns,
    diagnostic._extmark_id,
    { details = true }
  )
  if next(extmark) == nil then
    return diagnostic.lnum, diagnostic.col, diagnostic.end_lnum, diagnostic.end_col, true
  end

  return extmark[1], extmark[2], extmark[3].end_row, extmark[3].end_col, not extmark[3].invalid
end

--- @param diagnostics vim.Diagnostic[]?
--- @param use_logical_pos boolean
--- @return table<integer, vim.Diagnostic[]>
function M.diagnostic_lines(diagnostics, use_logical_pos)
  if not diagnostics then
    return {}
  end

  local diagnostics_by_line = {} --- @type table<integer, vim.Diagnostic[]>
  for _, diagnostic in ipairs(diagnostics) do
    local lnum --- @type integer
    local valid --- @type boolean

    if use_logical_pos then
      lnum, _, _, _, valid = M.get_logical_pos(diagnostic)
    else
      lnum, valid = diagnostic.lnum, true
    end

    if valid then
      local line_diagnostics = diagnostics_by_line[lnum]
      if not line_diagnostics then
        line_diagnostics = {}
        diagnostics_by_line[lnum] = line_diagnostics
      end
      line_diagnostics[#line_diagnostics + 1] = diagnostic
    end
  end
  return diagnostics_by_line
end

--- @param diagnostics table<integer, vim.Diagnostic[]>
--- @return vim.Diagnostic[]
function M.diagnostics_at_cursor(diagnostics)
  local lnum = api.nvim_win_get_cursor(0)[1] - 1

  if diagnostics[lnum] ~= nil then
    return diagnostics[lnum]
  end

  local cursor_diagnostics = {} --- @type vim.Diagnostic[]
  for _, line_diags in pairs(diagnostics) do
    for _, diagnostic in ipairs(line_diags) do
      if diagnostic.end_lnum and lnum >= diagnostic.lnum and lnum <= diagnostic.end_lnum then
        cursor_diagnostics[#cursor_diagnostics + 1] = diagnostic
      end
    end
  end
  return cursor_diagnostics
end

--- @param a vim.Diagnostic
--- @param b vim.Diagnostic
--- @param primary_key string
--- @param reverse boolean
--- @param col_fn? fun(diagnostic: vim.Diagnostic): integer
--- @return boolean
function M.diagnostic_cmp(a, b, primary_key, reverse, col_fn)
  local a_val, b_val --- @type integer, integer
  if col_fn then
    a_val, b_val = col_fn(a), col_fn(b)
  else
    a_val = a[primary_key] --[[@as integer]]
    b_val = b[primary_key] --[[@as integer]]
  end

  local cmp = function(x, y)
    if reverse then
      return x > y
    end
    return x < y
  end

  if a_val ~= b_val then
    return cmp(a_val, b_val)
  end
  if a.lnum ~= b.lnum then
    return cmp(a.lnum, b.lnum)
  end
  if a.col ~= b.col then
    return cmp(a.col, b.col)
  end
  if a.end_lnum ~= b.end_lnum then
    return cmp(a.end_lnum, b.end_lnum)
  end
  if a.end_col ~= b.end_col then
    return cmp(a.end_col, b.end_col)
  end

  return cmp(a._extmark_id or 0, b._extmark_id or 0)
end

--- @param format fun(diagnostic: vim.Diagnostic): string?
--- @param diagnostics vim.Diagnostic[]
--- @return vim.Diagnostic[]
function M.reformat_diagnostics(format, diagnostics)
  vim.validate('format', format, 'function')
  vim.validate('diagnostics', diagnostics, vim.islist, 'a list of diagnostics')

  local formatted = {} --- @type vim.Diagnostic[]
  for _, diagnostic in ipairs(diagnostics) do
    local message = format(diagnostic)
    if message ~= nil then
      local formatted_diagnostic = vim.deepcopy(diagnostic, true)
      formatted_diagnostic.message = message
      formatted[#formatted + 1] = formatted_diagnostic
    end
  end
  return formatted
end

return M
