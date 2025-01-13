local ts = vim.treesitter

local Range = require('vim.treesitter._range')

local api = vim.api

---Treesitter folding is done in two steps:
---(1) compute the fold levels with the syntax tree and cache the result (`compute_folds_levels`)
---(2) evaluate foldexpr for each window, which reads from the cache (`foldupdate`)
---@class TS.FoldInfo
---
---@field levels string[] the cached foldexpr result for each line
---@field levels0 integer[] the cached raw fold levels
---
---The range edited since the last invocation of the callback scheduled in on_bytes.
---Should compute fold levels in this range.
---@field on_bytes_range? Range2
---
---The range on which to evaluate foldexpr.
---When in insert mode, the evaluation is deferred to InsertLeave.
---@field foldupdate_range? Range2
---
---The treesitter parser associated with this buffer.
---@field parser? vim.treesitter.LanguageTree
local FoldInfo = {}
FoldInfo.__index = FoldInfo

---@private
---@param bufnr integer
function FoldInfo.new(bufnr)
  return setmetatable({
    levels0 = {},
    levels = {},
    parser = ts.get_parser(bufnr, nil, { error = false }),
  }, FoldInfo)
end

---@package
---@param srow integer
---@param erow integer 0-indexed, exclusive
function FoldInfo:remove_range(srow, erow)
  vim._list_remove(self.levels, srow + 1, erow)
  vim._list_remove(self.levels0, srow + 1, erow)
end

---@package
---@param srow integer
---@param erow integer 0-indexed, exclusive
function FoldInfo:add_range(srow, erow)
  vim._list_insert(self.levels, srow + 1, erow, -1)
  vim._list_insert(self.levels0, srow + 1, erow, -1)
end

---@param range Range2
---@param srow integer
---@param erow_old integer
---@param erow_new integer 0-indexed, exclusive
local function edit_range(range, srow, erow_old, erow_new)
  range[1] = math.min(srow, range[1])
  if erow_old <= range[2] then
    range[2] = range[2] + (erow_new - erow_old)
  end
  range[2] = math.max(range[2], erow_new)
end

-- TODO(lewis6991): Setup a decor provider so injections folds can be parsed
-- as the window is redrawn
---@param bufnr integer
---@param info TS.FoldInfo
---@param srow integer?
---@param erow integer? 0-indexed, exclusive
---@param callback function?
local function compute_folds_levels(bufnr, info, srow, erow, callback)
  srow = srow or 0
  erow = erow or api.nvim_buf_line_count(bufnr)

  local parser = info.parser
  if not parser then
    return
  end

  parser:parse(nil, function(_, trees)
    if not trees then
      return
    end

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
      for _, match, metadata in query:iter_matches(tree:root(), bufnr, math.max(srow - 1, 0), erow) do
        for id, nodes in pairs(match) do
          if query.captures[id] == 'fold' then
            local range = ts.get_range(nodes[1], bufnr, metadata[id])
            local start, _, stop, stop_col = Range.unpack4(range)

            if #nodes > 1 then
              -- assumes nodes are ordered by range
              local end_range = ts.get_range(nodes[#nodes], bufnr, metadata[id])
              local _, _, end_stop, end_stop_col = Range.unpack4(end_range)
              stop = end_stop
              stop_col = end_stop_col
            end

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

      -- Record the "real" level, so that it can be used as "base" of later compute_folds_levels().
      info.levels0[lnum] = adjusted
      info.levels[lnum] = prefix .. tostring(clamped)

      leave_prev = leave_line
      level0_prev = adjusted
    end

    if callback then
      callback()
    end
  end)
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
---@package
---@param srow integer
---@param erow integer 0-indexed, exclusive
function FoldInfo:foldupdate(bufnr, srow, erow)
  if self.foldupdate_range then
    edit_range(self.foldupdate_range, srow, erow, erow)
  else
    self.foldupdate_range = { srow, erow }
  end

  if api.nvim_get_mode().mode:match('^i') then
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
      callback = function()
        self:do_foldupdate(bufnr)
      end,
    })
    return
  end

  self:do_foldupdate(bufnr)
end

---@package
function FoldInfo:do_foldupdate(bufnr)
  -- InsertLeave is not executed when <C-C> is used for exiting the insert mode, leaving
  -- do_foldupdate untouched. If another execution of foldupdate consumes foldupdate_range, the
  -- InsertLeave do_foldupdate gets nil foldupdate_range. In that case, skip the update. This is
  -- correct because the update that consumed the range must have incorporated the range that
  -- InsertLeave meant to update.
  if not self.foldupdate_range then
    return
  end

  local srow, erow = self.foldupdate_range[1], self.foldupdate_range[2]
  self.foldupdate_range = nil
  for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
    if vim.wo[win].foldmethod == 'expr' then
      vim._foldupdate(win, srow, erow)
    end
  end
end

--- Schedule a function only if bufnr is loaded.
--- We schedule fold level computation for the following reasons:
--- * queries seem to use the old buffer state in on_bytes for some unknown reason;
--- * to avoid textlock;
--- * to avoid infinite recursion:
---   compute_folds_levels → parse → _do_callback → on_changedtree → compute_folds_levels.
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
    local srow_upd, erow_upd ---@type integer?, integer?
    local max_erow = api.nvim_buf_line_count(bufnr)
    -- TODO(ribru17): Replace this with a proper .all() awaiter once #19624 is resolved
    local iterations = 0
    for _, change in ipairs(tree_changes) do
      local srow, _, erow, ecol = Range.unpack4(change)
      -- If a parser doesn't have any ranges explicitly set, treesitter will
      -- return a range with end_row and end_bytes with a value of UINT32_MAX,
      -- so clip end_row to the max buffer line.
      -- TODO(lewis6991): Handle this generally
      if erow > max_erow then
        erow = max_erow
      elseif ecol > 0 then
        erow = erow + 1
      end
      -- Start from `srow - foldminlines`, because this edit may have shrunken the fold below limit.
      srow = math.max(srow - vim.wo.foldminlines, 0)
      srow_upd = srow_upd and math.min(srow_upd, srow) or srow
      erow_upd = erow_upd and math.max(erow_upd, erow) or erow
      compute_folds_levels(bufnr, foldinfo, srow, erow, function()
        iterations = iterations + 1
        if iterations == #tree_changes then
          foldinfo:foldupdate(bufnr, srow_upd, erow_upd)
        end
      end)
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

    if foldinfo.on_bytes_range then
      edit_range(foldinfo.on_bytes_range, start_row, end_row_old, end_row_new)
    else
      foldinfo.on_bytes_range = { start_row, end_row_new }
    end
    if foldinfo.foldupdate_range then
      edit_range(foldinfo.foldupdate_range, start_row, end_row_old, end_row_new)
    end

    -- This callback must not use on_bytes arguments, because they can be outdated when the callback
    -- is invoked. For example, `J` with non-zero count triggers multiple on_bytes before executing
    -- the scheduled callback. So we accumulate the edited ranges in `on_bytes_range`.
    schedule_if_loaded(bufnr, function()
      if not foldinfo.on_bytes_range then
        return
      end
      local srow, erow = foldinfo.on_bytes_range[1], foldinfo.on_bytes_range[2]
      foldinfo.on_bytes_range = nil
      -- Start from `srow - foldminlines`, because this edit may have shrunken the fold below limit.
      srow = math.max(srow - vim.wo.foldminlines, 0)
      compute_folds_levels(bufnr, foldinfo, srow, erow, function()
        foldinfo:foldupdate(bufnr, srow, erow)
      end)
    end)
  end
end

---@param lnum integer|nil
---@return string
function M.foldexpr(lnum)
  lnum = lnum or vim.v.lnum
  local bufnr = api.nvim_get_current_buf()

  if not foldinfos[bufnr] then
    foldinfos[bufnr] = FoldInfo.new(bufnr)
    api.nvim_create_autocmd('BufUnload', {
      buffer = bufnr,
      once = true,
      callback = function()
        foldinfos[bufnr] = nil
      end,
    })

    local parser = foldinfos[bufnr].parser
    if not parser then
      return '0'
    end

    compute_folds_levels(bufnr, foldinfos[bufnr])

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
    local buf = api.nvim_get_current_buf()
    local bufs = vim.v.option_type == 'global' and vim.tbl_keys(foldinfos)
      or foldinfos[buf] and { buf }
      or {}
    for _, bufnr in ipairs(bufs) do
      foldinfos[bufnr] = FoldInfo.new(bufnr)
      api.nvim_buf_call(bufnr, function()
        compute_folds_levels(bufnr, foldinfos[bufnr], nil, nil, function()
          foldinfos[bufnr]:foldupdate(bufnr, 0, api.nvim_buf_line_count(bufnr))
        end)
      end)
    end
  end,
})
return M
