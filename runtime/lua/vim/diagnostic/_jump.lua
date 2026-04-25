local api, if_nil = vim.api, vim.F.if_nil
local shared = require('vim.diagnostic._shared')
local store = require('vim.diagnostic._store')

--- @class (private) vim.diagnostic._JumpOpts : vim.diagnostic.JumpOpts
--- @field _highest? boolean
--- @field win_id? integer
--- @field cursor_position? [integer, integer]
--- @field float? table|boolean

--- @class (private) vim.diagnostic._jump
local M = {}

--- @param diagnostics vim.Diagnostic[]
local function filter_highest(diagnostics)
  table.sort(diagnostics, function(a, b)
    return shared.diagnostic_cmp(a, b, 'severity', false)
  end)

  -- Find the first diagnostic where the severity does not match the highest severity, and remove
  -- that element and all subsequent elements from the array
  local worst = (diagnostics[1] or {}).severity
  local len = #diagnostics
  for i = 2, len do
    if diagnostics[i].severity ~= worst then
      for j = i, len do
        diagnostics[j] = nil
      end
      break
    end
  end
end

--- @param search_forward boolean
--- @param opts vim.diagnostic.JumpOpts?
--- @param use_logical_pos boolean
--- @return vim.Diagnostic?
local function next_diagnostic(search_forward, opts, use_logical_pos)
  opts = opts or {}
  --- @cast opts vim.diagnostic._JumpOpts

  -- Support deprecated win_id alias
  if opts.win_id then
    vim.deprecate('opts.win_id', 'opts.winid', '0.13')
    opts.winid = opts.win_id
    opts.win_id = nil --- @diagnostic disable-line
  end

  -- Support deprecated cursor_position alias
  if opts.cursor_position then
    vim.deprecate('opts.cursor_position', 'opts.pos', '0.13')
    opts.pos = opts.cursor_position
    opts.cursor_position = nil --- @diagnostic disable-line
  end

  local winid = opts.winid or api.nvim_get_current_win()
  local bufnr = api.nvim_win_get_buf(winid)
  local position = opts.pos or api.nvim_win_get_cursor(winid)

  -- Adjust row to be 0-indexed
  position[1] = position[1] - 1

  local wrap = if_nil(opts.wrap, true)
  local diagnostics = store.get_diagnostics(bufnr, opts, true)

  if opts._highest then
    filter_highest(diagnostics)
  end

  local line_diagnostics = shared.diagnostic_lines(diagnostics, use_logical_pos)

  --- @param diagnostic vim.Diagnostic
  --- @return integer
  local function col_fn(diagnostic)
    return use_logical_pos and select(2, shared.get_logical_pos(diagnostic)) or diagnostic.col
  end

  local line_count = api.nvim_buf_line_count(bufnr)
  for i = 0, line_count do
    local offset = i * (search_forward and 1 or -1)
    local lnum = position[1] + offset
    if lnum < 0 or lnum >= line_count then
      if not wrap then
        return
      end
      lnum = (lnum + line_count) % line_count
    end

    if line_diagnostics[lnum] and not vim.tbl_isempty(line_diagnostics[lnum]) then
      local line_length = #api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, true)[1]
      local sort_diagnostics, is_next --- @type function, function
      if search_forward then
        sort_diagnostics = function(a, b)
          return shared.diagnostic_cmp(a, b, 'col', false, col_fn)
        end
        is_next = function(diagnostic)
          return math.min(col_fn(diagnostic), math.max(line_length - 1, 0)) > position[2]
        end
      else
        sort_diagnostics = function(a, b)
          return shared.diagnostic_cmp(a, b, 'col', true, col_fn)
        end
        is_next = function(diagnostic)
          return math.min(col_fn(diagnostic), math.max(line_length - 1, 0)) < position[2]
        end
      end

      table.sort(line_diagnostics[lnum], sort_diagnostics)
      if i == 0 then
        for _, diagnostic in ipairs(line_diagnostics[lnum]) do
          if is_next(diagnostic) then
            return diagnostic
          end
        end
      else
        return line_diagnostics[lnum][1]
      end
    end
  end
end

--- @param diagnostic vim.Diagnostic?
--- @param opts vim.diagnostic.JumpOpts?
local function goto_diagnostic(diagnostic, opts)
  if not diagnostic then
    api.nvim_echo({ { 'No more valid diagnostics to move to', 'WarningMsg' } }, true, {})
    return
  end

  opts = opts or {}
  --- @cast opts vim.diagnostic._JumpOpts

  -- Support deprecated win_id alias
  if opts.win_id then
    vim.deprecate('opts.win_id', 'opts.winid', '0.13')
    opts.winid = opts.win_id
    opts.win_id = nil --- @diagnostic disable-line
  end

  local winid = opts.winid or api.nvim_get_current_win()
  local lnum, col = shared.get_logical_pos(diagnostic)

  vim._with({ win = winid }, function()
    -- Save position in the window's jumplist
    vim.cmd("normal! m'")
    api.nvim_win_set_cursor(winid, { lnum + 1, col })
    -- Open folds under the cursor
    vim.cmd('normal! zv')
  end)

  if opts.float then
    vim.deprecate('opts.float', 'opts.on_jump', '0.14')
    local float_opts = opts.float
    float_opts = type(float_opts) == 'table' and float_opts or {}

    opts.on_jump = function(_, bufnr)
      vim.diagnostic.open_float(vim.tbl_extend('keep', float_opts, {
        bufnr = bufnr,
        scope = 'cursor',
        focus = false,
      }))
    end

    opts.float = nil --- @diagnostic disable-line
  end

  if opts.on_jump then
    vim.schedule(function()
      opts.on_jump(diagnostic, api.nvim_win_get_buf(winid))
    end)
  end
end

--- @param opts? vim.diagnostic.JumpOpts
--- @return vim.Diagnostic?
function M.get_prev(opts)
  return next_diagnostic(false, opts, false)
end

--- @param opts? vim.diagnostic.JumpOpts
--- @return table|false
function M.get_prev_pos(opts)
  vim.deprecate(
    'vim.diagnostic.get_prev_pos()',
    'access the lnum and col fields from get_prev() instead',
    '0.13'
  )
  local prev = M.get_prev(opts)
  if not prev then
    return false
  end

  return { prev.lnum, prev.col }
end

--- @param opts? vim.diagnostic.JumpOpts
function M.goto_prev(opts)
  vim.deprecate('vim.diagnostic.goto_prev()', 'vim.diagnostic.jump()', '0.13')
  opts = opts or {}
  opts.float = if_nil(opts.float, true) --- @diagnostic disable-line
  goto_diagnostic(M.get_prev(opts), opts)
end

--- @param opts? vim.diagnostic.JumpOpts
--- @return vim.Diagnostic?
function M.get_next(opts)
  return next_diagnostic(true, opts, false)
end

--- @param opts? vim.diagnostic.JumpOpts
--- @return table|false
function M.get_next_pos(opts)
  vim.deprecate(
    'vim.diagnostic.get_next_pos()',
    'access the lnum and col fields from get_next() instead',
    '0.13'
  )
  local next = M.get_next(opts)
  if not next then
    return false
  end

  return { next.lnum, next.col }
end

--- @param opts vim.diagnostic.JumpOpts
--- @return vim.Diagnostic?
function M.jump(opts)
  vim.validate('opts', opts, 'table')

  -- One of "diagnostic" or "count" must be provided
  assert(
    opts.diagnostic or opts.count,
    'One of "diagnostic" or "count" must be specified in the options to vim.diagnostic.jump()'
  )

  -- Apply configuration options from vim.diagnostic.config()
  local config = assert(vim.diagnostic.config()).jump or {}
  opts = vim.tbl_deep_extend('keep', opts, config)
  --- @cast opts vim.diagnostic._JumpOpts

  if opts.diagnostic then
    goto_diagnostic(opts.diagnostic, opts)
    return opts.diagnostic
  end

  local count = opts.count
  if count == 0 then
    return nil
  end

  -- Support deprecated cursor_position alias
  if opts.cursor_position then
    vim.deprecate('opts.cursor_position', 'opts.pos', '0.13')
    opts.pos = opts.cursor_position
    opts.cursor_position = nil --- @diagnostic disable-line
  end

  local diagnostic --- @type vim.Diagnostic?
  while count ~= 0 do
    local next = next_diagnostic(count > 0, opts, true)
    if not next then
      break
    end

    -- Update cursor position
    opts.pos = { next.lnum + 1, next.col }

    if count > 0 then
      count = count - 1
    else
      count = count + 1
    end
    diagnostic = next
  end

  goto_diagnostic(diagnostic, opts)
  return diagnostic
end

--- @param opts? vim.diagnostic.JumpOpts
function M.goto_next(opts)
  vim.deprecate('vim.diagnostic.goto_next()', 'vim.diagnostic.jump()', '0.13')
  opts = opts or {}
  opts.float = if_nil(opts.float, true) --- @diagnostic disable-line
  goto_diagnostic(M.get_next(opts), opts)
end

return M
