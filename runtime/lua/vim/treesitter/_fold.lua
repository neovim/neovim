local ts = vim.treesitter

local Range = require('vim.treesitter._range')

local api = vim.api

---@class TS.FoldInfo
---@field levels string[] the foldexpr result for each line
---@field levels0 integer[] the raw fold levels
---@field edits? {[1]: integer, [2]: integer} line range edited since the last invocation of the callback scheduled in on_bytes. 0-indexed, end-exclusive.
local FoldInfo = {}
FoldInfo.__index = FoldInfo

---@private
function FoldInfo.new()
  return setmetatable({
    levels0 = {},
    levels = {},
  }, FoldInfo)
end

--- Efficiently remove items from middle of a list a list.
---
--- Calling table.remove() in a loop will re-index the tail of the table on
--- every iteration, instead this function will re-index  the table exactly
--- once.
---
--- Based on https://stackoverflow.com/questions/12394841/safely-remove-items-from-an-array-table-while-iterating/53038524#53038524
---
---@param t any[]
---@param first integer
---@param last integer
local function list_remove(t, first, last)
  local n = #t
  for i = 0, n - first do
    t[first + i] = t[last + 1 + i]
    t[last + 1 + i] = nil
  end
end

---@package
---@param srow integer
---@param erow integer 0-indexed, exclusive
function FoldInfo:remove_range(srow, erow)
  list_remove(self.levels, srow + 1, erow)
  list_remove(self.levels0, srow + 1, erow)
end

--- Efficiently insert items into the middle of a list.
---
--- Calling table.insert() in a loop will re-index the tail of the table on
--- every iteration, instead this function will re-index  the table exactly
--- once.
---
--- Based on https://stackoverflow.com/questions/12394841/safely-remove-items-from-an-array-table-while-iterating/53038524#53038524
---
---@param t any[]
---@param first integer
---@param last integer
---@param v any
local function list_insert(t, first, last, v)
  local n = #t

  -- Shift table forward
  for i = n - first, 0, -1 do
    t[last + 1 + i] = t[first + i]
  end

  -- Fill in new values
  for i = first, last do
    t[i] = v
  end
end

---@package
---@param srow integer
---@param erow integer 0-indexed, exclusive
function FoldInfo:add_range(srow, erow)
  list_insert(self.levels, srow + 1, erow, '=')
  list_insert(self.levels0, srow + 1, erow, -1)
end

---@package
---@param srow integer
---@param erow_old integer
---@param erow_new integer 0-indexed, exclusive
function FoldInfo:edit_range(srow, erow_old, erow_new)
  if self.edits then
    self.edits[1] = math.min(srow, self.edits[1])
    if erow_old <= self.edits[2] then
      self.edits[2] = self.edits[2] + (erow_new - erow_old)
    end
    self.edits[2] = math.max(self.edits[2], erow_new)
  else
    self.edits = { srow, erow_new }
  end
end

---@package
---@return integer? srow
---@return integer? erow 0-indexed, exclusive
function FoldInfo:flush_edit()
  if self.edits then
    local srow, erow = self.edits[1], self.edits[2]
    self.edits = nil
    return srow, erow
  end
end

--- If a parser doesn't have any ranges explicitly set, treesitter will
--- return a range with end_row and end_bytes with a value of UINT32_MAX,
--- so clip end_row to the max buffer line.
---
--- TODO(lewis6991): Handle this generally
---
--- @param bufnr integer
--- @param erow integer? 0-indexed, exclusive
--- @return integer
local function normalise_erow(bufnr, erow)
  local max_erow = api.nvim_buf_line_count(bufnr)
  return math.min(erow or max_erow, max_erow)
end

-- TODO(lewis6991): Setup a decor provider so injections folds can be parsed
-- as the window is redrawn
---@param bufnr integer
---@param info TS.FoldInfo
---@param srow integer?
---@param erow integer? 0-indexed, exclusive
---@param parse_injections? boolean
local function get_folds_levels(bufnr, info, srow, erow, parse_injections)
  srow = srow or 0
  erow = normalise_erow(bufnr, erow)

  local parser = ts.get_parser(bufnr)

  parser:parse(parse_injections and { srow, erow } or nil)

  local enter_counts = {} ---@type table<integer, integer>
  local leave_counts = {} ---@type table<integer, integer>
  local prev_start = -1
  local prev_stop = -1

  parser:for_each_tree(function(tree, ltree)
    local query = ts.query.get(ltree:lang(), 'folds')
    if not query then
      return
    end

    -- Collect folds starting from srow - 1, because we should first subtract the folds that end at
    -- srow - 1 from the level of srow - 1 to get accurate level of srow.
    for id, node, metadata in query:iter_captures(tree:root(), bufnr, math.max(srow - 1, 0), erow) do
      if query.captures[id] == 'fold' then
        local range = ts.get_range(node, bufnr, metadata[id])
        local start, _, stop, stop_col = Range.unpack4(range)

        if stop_col == 0 then
          stop = stop - 1
        end

        local fold_length = stop - start + 1

        -- Fold only multiline nodes that are not exactly the same as previously met folds
        -- Checking against just the previously found fold is sufficient if nodes
        -- are returned in preorder or postorder when traversing tree
        if
          fold_length > vim.wo.foldminlines and not (start == prev_start and stop == prev_stop)
        then
          enter_counts[start + 1] = (enter_counts[start + 1] or 0) + 1
          leave_counts[stop + 1] = (leave_counts[stop + 1] or 0) + 1
          prev_start = start
          prev_stop = stop
        end
      end
    end
  end)

  local nestmax = vim.wo.foldnestmax
  local level0_prev = info.levels0[srow] or 0
  local leave_prev = leave_counts[srow] or 0

  -- We now have the list of fold opening and closing, fill the gaps and mark where fold start
  for lnum = srow + 1, erow do
    local enter_line = enter_counts[lnum] or 0
    local leave_line = leave_counts[lnum] or 0
    local level0 = level0_prev - leave_prev + enter_line

    -- Determine if it's the start/end of a fold
    -- NB: vim's fold-expr interface does not have a mechanism to indicate that
    -- two (or more) folds start at this line, so it cannot distinguish between
    --  ( \n ( \n )) \n (( \n ) \n )
    -- versus
    --  ( \n ( \n ) \n ( \n ) \n )
    -- Both are represented by ['>1', '>2', '2', '>2', '2', '1'], and
    -- vim interprets as the second case.
    -- If it did have such a mechanism, (clamped - clamped_prev)
    -- would be the correct number of starts to pass on.
    local adjusted = level0 ---@type integer
    local prefix = ''
    if enter_line > 0 then
      prefix = '>'
      if leave_line > 0 then
        -- If this line ends a fold f1 and starts a fold f2, then move f1's end to the previous line
        -- so that f2 gets the correct level on this line. This may reduce the size of f1 below
        -- foldminlines, but we don't handle it for simplicity.
        adjusted = level0 - leave_line
        leave_line = 0
      end
    end

    -- Clamp at foldnestmax.
    local clamped = adjusted
    if adjusted > nestmax then
      prefix = ''
      clamped = nestmax
    end

    -- Record the "real" level, so that it can be used as "base" of later get_folds_levels().
    info.levels0[lnum] = adjusted
    info.levels[lnum] = prefix .. tostring(clamped)

    leave_prev = leave_line
    level0_prev = adjusted
  end
end

local M = {}

---@type table<integer,TS.FoldInfo>
local foldinfos = {}

local group = api.nvim_create_augroup('treesitter/fold', {})

--- Update the folds in the windows that contain the buffer and use expr foldmethod (assuming that
--- the user doesn't use different foldexpr for the same buffer).
---
--- Nvim usually automatically updates folds when text changes, but it doesn't work here because
--- FoldInfo update is scheduled. So we do it manually.
local function foldupdate(bufnr)
  local function do_update()
    for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
      api.nvim_win_call(win, function()
        if vim.wo.foldmethod == 'expr' then
          vim._foldupdate()
        end
      end)
    end
  end

  if api.nvim_get_mode().mode == 'i' then
    -- foldUpdate() is guarded in insert mode. So update folds on InsertLeave
    if #(api.nvim_get_autocmds({
      group = group,
      buffer = bufnr,
    })) > 0 then
      return
    end
    api.nvim_create_autocmd('InsertLeave', {
      group = group,
      buffer = bufnr,
      once = true,
      callback = do_update,
    })
    return
  end

  do_update()
end

--- Schedule a function only if bufnr is loaded.
--- We schedule fold level computation for the following reasons:
--- * queries seem to use the old buffer state in on_bytes for some unknown reason;
--- * to avoid textlock;
--- * to avoid infinite recursion:
---   get_folds_levels → parse → _do_callback → on_changedtree → get_folds_levels.
---@param bufnr integer
---@param fn function
local function schedule_if_loaded(bufnr, fn)
  vim.schedule(function()
    if not api.nvim_buf_is_loaded(bufnr) then
      return
    end
    fn()
  end)
end

---@param bufnr integer
---@param foldinfo TS.FoldInfo
---@param tree_changes Range4[]
local function on_changedtree(bufnr, foldinfo, tree_changes)
  schedule_if_loaded(bufnr, function()
    for _, change in ipairs(tree_changes) do
      local srow, _, erow, ecol = Range.unpack4(change)
      if ecol > 0 then
        erow = erow + 1
      end
      -- Start from `srow - foldminlines`, because this edit may have shrunken the fold below limit.
      get_folds_levels(bufnr, foldinfo, math.max(srow - vim.wo.foldminlines, 0), erow)
    end
    if #tree_changes > 0 then
      foldupdate(bufnr)
    end
  end)
end

---@param bufnr integer
---@param foldinfo TS.FoldInfo
---@param start_row integer
---@param old_row integer
---@param old_col integer
---@param new_row integer
---@param new_col integer
local function on_bytes(bufnr, foldinfo, start_row, start_col, old_row, old_col, new_row, new_col)
  -- extend the end to fully include the range
  local end_row_old = start_row + old_row + 1
  local end_row_new = start_row + new_row + 1

  if new_row ~= old_row then
    -- foldexpr can be evaluated before the scheduled callback is invoked. So it may observe the
    -- outdated levels, which may spuriously open the folds that didn't change. So we should shift
    -- folds as accurately as possible. For this to be perfectly accurate, we should track the
    -- actual TSNodes that account for each fold, and compare the node's range with the edited
    -- range. But for simplicity, we just check whether the start row is completely removed (e.g.,
    -- `dd`) or shifted (e.g., `o`).
    if new_row < old_row then
      if start_col == 0 and new_row == 0 and new_col == 0 then
        foldinfo:remove_range(start_row, start_row + (end_row_old - end_row_new))
      else
        foldinfo:remove_range(end_row_new, end_row_old)
      end
    else
      if start_col == 0 and old_row == 0 and old_col == 0 then
        foldinfo:add_range(start_row, start_row + (end_row_new - end_row_old))
      else
        foldinfo:add_range(end_row_old, end_row_new)
      end
    end
    foldinfo:edit_range(start_row, end_row_old, end_row_new)

    -- This callback must not use on_bytes arguments, because they can be outdated when the callback
    -- is invoked. For example, `J` with non-zero count triggers multiple on_bytes before executing
    -- the scheduled callback. So we should collect the edits.
    schedule_if_loaded(bufnr, function()
      local srow, erow = foldinfo:flush_edit()
      if not srow then
        return
      end
      -- Start from `srow - foldminlines`, because this edit may have shrunken the fold below limit.
      get_folds_levels(bufnr, foldinfo, math.max(srow - vim.wo.foldminlines, 0), erow)
      foldupdate(bufnr)
    end)
  end
end

---@package
---@param lnum integer|nil
---@return string
function M.foldexpr(lnum)
  lnum = lnum or vim.v.lnum
  local bufnr = api.nvim_get_current_buf()

  local parser = vim.F.npcall(ts.get_parser, bufnr)
  if not parser then
    return '0'
  end

  if not foldinfos[bufnr] then
    foldinfos[bufnr] = FoldInfo.new()
    get_folds_levels(bufnr, foldinfos[bufnr])

    parser:register_cbs({
      on_changedtree = function(tree_changes)
        on_changedtree(bufnr, foldinfos[bufnr], tree_changes)
      end,

      on_bytes = function(_, _, start_row, start_col, _, old_row, old_col, _, new_row, new_col, _)
        on_bytes(bufnr, foldinfos[bufnr], start_row, start_col, old_row, old_col, new_row, new_col)
      end,

      on_detach = function()
        foldinfos[bufnr] = nil
      end,
    })
  end

  return foldinfos[bufnr].levels[lnum] or '0'
end

api.nvim_create_autocmd('OptionSet', {
  pattern = { 'foldminlines', 'foldnestmax' },
  desc = 'Refresh treesitter folds',
  callback = function()
    for _, bufnr in ipairs(vim.tbl_keys(foldinfos)) do
      foldinfos[bufnr] = FoldInfo.new()
      get_folds_levels(bufnr, foldinfos[bufnr])
      foldupdate(bufnr)
    end
  end,
})

---@package
---@return { [1]: string, [2]: string[] }[]|string
function M.foldtext()
  local foldstart = vim.v.foldstart
  local bufnr = api.nvim_get_current_buf()

  ---@type boolean, LanguageTree
  local ok, parser = pcall(ts.get_parser, bufnr)
  if not ok then
    return vim.fn.foldtext()
  end

  local query = ts.query.get(parser:lang(), 'highlights')
  if not query then
    return vim.fn.foldtext()
  end

  local tree = parser:parse({ foldstart - 1, foldstart })[1]

  local line = api.nvim_buf_get_lines(bufnr, foldstart - 1, foldstart, false)[1]
  if not line then
    return vim.fn.foldtext()
  end

  ---@type { [1]: string, [2]: string[], range: { [1]: integer, [2]: integer } }[] | { [1]: string, [2]: string[] }[]
  local result = {}

  local line_pos = 0

  for id, node, metadata in query:iter_captures(tree:root(), 0, foldstart - 1, foldstart) do
    local name = query.captures[id]
    local start_row, start_col, end_row, end_col = node:range()

    local priority = tonumber(metadata.priority or vim.highlight.priorities.treesitter)

    if start_row == foldstart - 1 and end_row == foldstart - 1 then
      -- check for characters ignored by treesitter
      if start_col > line_pos then
        table.insert(result, {
          line:sub(line_pos + 1, start_col),
          {},
          range = { line_pos, start_col },
        })
      end
      line_pos = end_col

      -- get possible semantic highlight for the symbol
      local extmarks = vim.api.nvim_buf_get_extmarks(
        bufnr,
        -1,
        { foldstart - 1, start_col },
        { foldstart - 1, end_col - 1 },
        {
          details = true,
          hl_name = true,
          type = 'highlight',
        }
      )
      -- ensure priority sort (buf_get_extmarks returns "traversal order")
      table.sort(extmarks, function(a, b)
        return a[4].priority < b[4].priority
      end)
      local extmark_hl = extmarks[1]

      local text = line:sub(start_col + 1, end_col)
      local highlights = {
        { '@' .. name, extmark_hl and (priority - 1) or priority },
        extmark_hl and { extmark_hl[4].hl_group, priority },
      }
      table.insert(result, { text, highlights, range = { start_col, end_col } })
    end
  end

  local i = 1
  while i <= #result do
    -- find first capture that is not in current range and apply highlights on the way
    local j = i + 1
    while
      j <= #result
      and result[j].range[1] >= result[i].range[1]
      and result[j].range[2] <= result[i].range[2]
    do
      for k, v in ipairs(result[i][2]) do
        if not vim.tbl_contains(result[j][2], v) then
          table.insert(result[j][2], k, v)
        end
      end
      j = j + 1
    end

    -- remove the parent capture if it is split into children
    if j > i + 1 then
      table.remove(result, i)
    else
      -- highlights need to be sorted by priority, on equal prio, the deeper nested capture (earlier
      -- in list) should be considered higher prio
      if #result[i][2] > 1 then
        table.sort(result[i][2], function(a, b)
          return a[2] < b[2]
        end)
      end

      result[i][2] = vim.tbl_map(function(tbl)
        return tbl[1]
      end, result[i][2])
      result[i] = { result[i][1], result[i][2] }

      i = i + 1
    end
  end

  local extmarks = vim.api.nvim_buf_get_extmarks(
    0,
    -1,
    { foldstart - 1, 1 },
    { foldstart - 1, -1 },
    {
      details = true,
      hl_name = true,
      type = 'virt_text',
    }
  )

  local merged_vt = {}
  local last_found = 0

  -- merge inline extmarks into the line's virt text chunks
  for _, mark in ipairs(extmarks) do
    if mark[4].virt_text and mark[4].virt_text_pos == 'inline' then
      local virt_text = mark[4].virt_text --[[@as any[] ]]
      local col_start = mark[3] --[[@as integer]]
      local cur_width = 0
      for idx, res_chunk in ipairs(result) do
        cur_width = cur_width + #res_chunk[1]
        if cur_width >= col_start then
          if idx > last_found then
            table.insert(merged_vt, res_chunk)
          end
          last_found = idx
          for _, vt in ipairs(virt_text) do
            table.insert(merged_vt, vt)
          end
          break
        end
        if idx > last_found then
          table.insert(merged_vt, res_chunk)
        end
      end
    end
  end

  -- add the remaining virt text chunks to the result
  for idx = last_found + 1, #result do
    table.insert(merged_vt, result[idx])
  end

  return merged_vt
end

return M
