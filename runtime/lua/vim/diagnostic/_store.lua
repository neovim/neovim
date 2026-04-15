local api = vim.api

local severity_module = require('vim.diagnostic._severity')

--- @class (private) vim.diagnostic._store
local M = {}

-- bufnr -> ns -> Diagnostic[]
local diagnostic_cache = {} --- @type table<integer,table<integer,vim.Diagnostic[]?>>

local group = api.nvim_create_augroup('nvim.diagnostic.buf_wipeout', {})
setmetatable(diagnostic_cache, {
  --- @param t table<integer,vim.Diagnostic[]>
  --- @param bufnr integer
  __index = function(t, bufnr)
    assert(bufnr > 0, 'Invalid buffer number')
    api.nvim_create_autocmd('BufWipeout', {
      group = group,
      buf = bufnr,
      callback = function()
        rawset(t, bufnr, nil)
      end,
    })
    t[bufnr] = {}
    return t[bufnr]
  end,
})

--- @param bufnr integer
--- @param namespace integer
--- @param d vim.Diagnostic.Set
local function norm_diag(bufnr, namespace, d)
  vim.validate('diagnostic.lnum', d.lnum, 'number')
  local d1 = d --[[@as vim.Diagnostic]]
  d1.severity = d.severity and severity_module.to_severity(d.severity)
    or vim.diagnostic.severity.ERROR
  d1.end_lnum = d.end_lnum or d.lnum
  d1.col = d.col or 0
  d1.end_col = d.end_col or d.col or 0
  d1.namespace = namespace
  d1.bufnr = bufnr
end

--- Execute a given function now if the given buffer is already loaded or once it is loaded later.
---
--- @param bufnr integer Buffer number
--- @param fn fun()
--- @return integer?
local function once_buf_loaded(bufnr, fn)
  if api.nvim_buf_is_loaded(bufnr) then
    fn()
  else
    return api.nvim_create_autocmd('BufRead', {
      buf = bufnr,
      once = true,
      callback = function()
        fn()
      end,
    })
  end
end

--- @param bufnr integer?
--- @param opts vim.diagnostic.GetOpts?
--- @param clamp boolean
--- @return vim.Diagnostic[]
function M.get_diagnostics(bufnr, opts, clamp)
  opts = opts or {}

  local namespace = opts.namespace

  if type(namespace) == 'number' then
    namespace = { namespace }
  end

  --- @cast namespace integer[]

  --- @type vim.Diagnostic[]
  local diagnostics = {}

  -- Memoized results of buf_line_count per bufnr
  --- @type table<integer,integer>
  local buf_line_count = setmetatable({}, {
    --- @param t table<integer,integer>
    --- @param k integer
    --- @return integer
    __index = function(t, k)
      t[k] = api.nvim_buf_line_count(k)
      return rawget(t, k)
    end,
  })

  local match_severity = opts.severity and severity_module.severity_predicate(opts.severity)
    or function(_)
      return true
    end

  --- @param b integer
  --- @param d vim.Diagnostic
  local match_enablement = function(d, b)
    if opts.enabled == nil then
      return true
    end

    local enabled = vim.diagnostic.is_enabled({ bufnr = b, ns_id = d.namespace })

    return (enabled and opts.enabled) or (not enabled and not opts.enabled)
  end

  --- @param b integer
  --- @param d vim.Diagnostic
  local function add(b, d)
    if
      match_severity(d)
      and match_enablement(d, b)
      and (not opts.lnum or (opts.lnum >= d.lnum and opts.lnum <= (d.end_lnum or d.lnum)))
    then
      if clamp and api.nvim_buf_is_loaded(b) then
        local line_count = buf_line_count[b] - 1
        if
          d.lnum > line_count
          or d.end_lnum > line_count
          or d.lnum < 0
          or d.end_lnum < 0
          or d.col < 0
          or d.end_col < 0
        then
          d = vim.deepcopy(d, true)
          d.lnum = math.max(math.min(d.lnum, line_count), 0)
          d.end_lnum = math.max(math.min(d.end_lnum, line_count), 0)
          d.col = math.max(d.col, 0)
          d.end_col = math.max(d.end_col, 0)
        end
      end
      table.insert(diagnostics, d)
    end
  end

  --- @param buf integer
  --- @param diags vim.Diagnostic[]
  local function add_all_diags(buf, diags)
    for _, diagnostic0 in pairs(diags) do
      add(buf, diagnostic0)
    end
  end

  if not namespace and not bufnr then
    for buf, ns_diags in pairs(diagnostic_cache) do
      for _, diags in pairs(ns_diags) do
        add_all_diags(buf, diags)
      end
    end
  elseif not namespace then
    bufnr = vim._resolve_bufnr(bufnr)
    for iter_namespace in pairs(diagnostic_cache[bufnr]) do
      add_all_diags(bufnr, diagnostic_cache[bufnr][iter_namespace])
    end
  elseif bufnr == nil then
    for b, t in pairs(diagnostic_cache) do
      for _, iter_namespace in ipairs(namespace) do
        add_all_diags(b, t[iter_namespace] or {})
      end
    end
  else
    bufnr = vim._resolve_bufnr(bufnr)
    for _, iter_namespace in ipairs(namespace) do
      add_all_diags(bufnr, diagnostic_cache[bufnr][iter_namespace] or {})
    end
  end

  return diagnostics
end

--- @return integer[]
function M.get_bufnrs()
  return vim.tbl_keys(diagnostic_cache)
end

--- @param bufnr integer
--- @return integer[]
function M.get_buf_namespaces(bufnr)
  return vim.tbl_keys(diagnostic_cache[vim._resolve_bufnr(bufnr)])
end

--- @param namespace integer
--- @param bufnr integer
function M.clear(namespace, bufnr)
  diagnostic_cache[vim._resolve_bufnr(bufnr)][namespace] = nil
end

--- @param bufnr integer
function M.drop_buf(bufnr)
  diagnostic_cache[vim._resolve_bufnr(bufnr)] = nil
end

--- Set diagnostics for the given namespace and buffer.
---
--- @param namespace integer The diagnostic namespace
--- @param bufnr integer Buffer number
--- @param diagnostics vim.Diagnostic.Set[]
function M.set(namespace, bufnr, diagnostics)
  vim.validate('namespace', namespace, 'number')
  vim.validate('bufnr', bufnr, 'number')
  vim.validate('diagnostics', diagnostics, vim.islist, 'a list of diagnostics')

  bufnr = vim._resolve_bufnr(bufnr)

  for _, diagnostic0 in ipairs(diagnostics) do
    norm_diag(bufnr, namespace, diagnostic0)
  end

  --- @cast diagnostics vim.Diagnostic[]

  if vim.tbl_isempty(diagnostics) then
    diagnostic_cache[bufnr][namespace] = nil
  else
    diagnostic_cache[bufnr][namespace] = diagnostics
  end

  -- Compute positions, set them as extmarks, and store in diagnostic._extmark_id
  -- (used by get_logical_pos to adjust positions).
  once_buf_loaded(bufnr, function()
    local ns = vim.diagnostic.get_namespace(namespace)

    if not ns.user_data.location_ns then
      ns.user_data.location_ns =
        api.nvim_create_namespace(string.format('nvim.%s.diagnostic', ns.name))
    end

    api.nvim_buf_clear_namespace(bufnr, ns.user_data.location_ns, 0, -1)

    local lines = api.nvim_buf_get_lines(bufnr, 0, -1, true)
    -- set extmarks at diagnostic locations to preserve logical positions despite text changes
    for _, diagnostic0 in ipairs(diagnostics) do
      local last_row = #lines - 1
      local row = math.max(0, math.min(diagnostic0.lnum, last_row))
      local row_len = #lines[row + 1]
      local col = math.max(0, math.min(diagnostic0.col, row_len - 1))

      local end_row = math.max(0, math.min(diagnostic0.end_lnum or row, last_row))
      local end_row_len = #lines[end_row + 1]
      local end_col = math.max(0, math.min(diagnostic0.end_col or col, end_row_len))

      if end_row == row then
        -- avoid starting an extmark beyond end of the line
        if end_col == col then
          end_col = math.min(end_col + 1, end_row_len)
        end
      else
        -- avoid ending an extmark before start of the line
        if end_col == 0 then
          end_row = end_row - 1

          local end_line = lines[end_row + 1]

          if not end_line then
            error(
              'Failed to adjust diagnostic position to the end of a previous line. #lines in a buffer: '
                .. #lines
                .. ', lnum: '
                .. diagnostic0.lnum
                .. ', col: '
                .. diagnostic0.col
                .. ', end_lnum: '
                .. diagnostic0.end_lnum
                .. ', end_col: '
                .. diagnostic0.end_col
            )
          end

          end_col = #end_line
        end
      end

      diagnostic0._extmark_id =
        api.nvim_buf_set_extmark(bufnr, ns.user_data.location_ns, row, col, {
          end_row = end_row,
          end_col = end_col,
          invalidate = true,
        })
    end
  end)
end

--- @param bufnr integer? Buffer number to get diagnostics from. Use 0 for
---                      current buffer or nil for all buffers.
--- @param opts? vim.diagnostic.GetOpts
--- @return vim.Diagnostic[] : Fields `bufnr`, `end_lnum`, `end_col`, and `severity`
---                           are guaranteed to be present.
function M.get(bufnr, opts)
  vim.validate('bufnr', bufnr, 'number', true)
  vim.validate('opts', opts, 'table', true)

  return vim.deepcopy(M.get_diagnostics(bufnr, opts, false), true)
end

--- @param bufnr? integer Buffer number to get diagnostics from. Use 0 for
---                      current buffer or nil for all buffers.
--- @param opts? vim.diagnostic.GetOpts
--- @return table<integer, integer> : Table with actually present severity values as keys
---                (see |diagnostic-severity|) and integer counts as values.
function M.count(bufnr, opts)
  vim.validate('bufnr', bufnr, 'number', true)
  vim.validate('opts', opts, 'table', true)

  local diagnostics = M.get_diagnostics(bufnr, opts, false)
  local count = {} --- @type table<integer,integer>
  for _, d in ipairs(diagnostics) do
    count[d.severity] = (count[d.severity] or 0) + 1
  end
  return count
end

return M
