local Range = require('vim.treesitter._range')

local api = vim.api

---@class TS.FoldInfo
---@field levels table<integer,string>
---@field levels0 table<integer,integer>
---@field private start_counts table<integer,integer>
---@field private stop_counts table<integer,integer>
local FoldInfo = {}
FoldInfo.__index = FoldInfo

---@private
function FoldInfo.new()
  return setmetatable({
    start_counts = {},
    stop_counts = {},
    levels0 = {},
    levels = {},
  }, FoldInfo)
end

---@package
---@param srow integer
---@param erow integer
function FoldInfo:invalidate_range(srow, erow)
  for i = srow, erow do
    self.start_counts[i + 1] = nil
    self.stop_counts[i + 1] = nil
    self.levels0[i + 1] = nil
    self.levels[i + 1] = nil
  end
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
---@param erow integer
function FoldInfo:remove_range(srow, erow)
  list_remove(self.levels, srow + 1, erow)
  list_remove(self.levels0, srow + 1, erow)
  list_remove(self.start_counts, srow + 1, erow)
  list_remove(self.stop_counts, srow + 1, erow)
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
---@param erow integer
function FoldInfo:add_range(srow, erow)
  list_insert(self.levels, srow + 1, erow, '-1')
  list_insert(self.levels0, srow + 1, erow, -1)
  list_insert(self.start_counts, srow + 1, erow, nil)
  list_insert(self.stop_counts, srow + 1, erow, nil)
end

---@package
---@param lnum integer
function FoldInfo:add_start(lnum)
  self.start_counts[lnum] = (self.start_counts[lnum] or 0) + 1
end

---@package
---@param lnum integer
function FoldInfo:add_stop(lnum)
  self.stop_counts[lnum] = (self.stop_counts[lnum] or 0) + 1
end

---@package
---@param lnum integer
---@return integer
function FoldInfo:get_start(lnum)
  return self.start_counts[lnum] or 0
end

---@package
---@param lnum integer
---@return integer
function FoldInfo:get_stop(lnum)
  return self.stop_counts[lnum] or 0
end

local function trim_level(level)
  local max_fold_level = vim.wo.foldnestmax
  if level > max_fold_level then
    return max_fold_level
  end
  return level
end

---@param bufnr integer
---@param info TS.FoldInfo
---@param srow integer?
---@param erow integer?
local function get_folds_levels(bufnr, info, srow, erow)
  srow = srow or 0
  erow = erow or api.nvim_buf_line_count(bufnr)

  info:invalidate_range(srow, erow)

  local prev_start = -1
  local prev_stop = -1

  vim.treesitter.get_parser(bufnr):for_each_tree(function(tree, ltree)
    local query = vim.treesitter.query.get(ltree:lang(), 'folds')
    if not query then
      return
    end

    -- erow in query is end-exclusive
    local q_erow = erow and erow + 1 or -1

    for id, node, metadata in query:iter_captures(tree:root(), bufnr, srow or 0, q_erow) do
      if query.captures[id] == 'fold' then
        local range = vim.treesitter.get_range(node, bufnr, metadata[id])
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
          info:add_start(start + 1)
          info:add_stop(stop + 1)
          prev_start = start
          prev_stop = stop
        end
      end
    end
  end)

  local current_level = info.levels0[srow] or 0

  -- We now have the list of fold opening and closing, fill the gaps and mark where fold start
  for lnum = srow + 1, erow + 1 do
    local last_trimmed_level = trim_level(current_level)
    current_level = current_level + info:get_start(lnum)
    info.levels0[lnum] = current_level

    local trimmed_level = trim_level(current_level)
    current_level = current_level - info:get_stop(lnum)

    -- Determine if it's the start/end of a fold
    -- NB: vim's fold-expr interface does not have a mechanism to indicate that
    -- two (or more) folds start at this line, so it cannot distinguish between
    --  ( \n ( \n )) \n (( \n ) \n )
    -- versus
    --  ( \n ( \n ) \n ( \n ) \n )
    -- If it did have such a mechanism, (trimmed_level - last_trimmed_level)
    -- would be the correct number of starts to pass on.
    local prefix = ''
    if trimmed_level - last_trimmed_level > 0 then
      prefix = '>'
    end

    info.levels[lnum] = prefix .. tostring(trimmed_level)
  end
end

local M = {}

---@type table<integer,TS.FoldInfo>
local foldinfos = {}

local function recompute_folds()
  if api.nvim_get_mode().mode == 'i' then
    -- foldUpdate() is guarded in insert mode. So update folds on InsertLeave
    api.nvim_create_autocmd('InsertLeave', {
      once = true,
      callback = vim._foldupdate,
    })
    return
  end

  vim._foldupdate()
end

--- Schedule a function only if bufnr is loaded
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
  -- For some reason, queries seem to use the old buffer state in on_bytes.
  -- Get around this by scheduling and manually updating folds.
  schedule_if_loaded(bufnr, function()
    for _, change in ipairs(tree_changes) do
      local srow, _, erow = Range.unpack4(change)
      get_folds_levels(bufnr, foldinfo, srow, erow)
    end
    recompute_folds()
  end)
end

---@param bufnr integer
---@param foldinfo TS.FoldInfo
---@param start_row integer
---@param old_row integer
---@param new_row integer
local function on_bytes(bufnr, foldinfo, start_row, old_row, new_row)
  local end_row_old = start_row + old_row
  local end_row_new = start_row + new_row

  if new_row < old_row then
    foldinfo:remove_range(end_row_new, end_row_old)
  elseif new_row > old_row then
    foldinfo:add_range(start_row, end_row_new)
    schedule_if_loaded(bufnr, function()
      get_folds_levels(bufnr, foldinfo, start_row, end_row_new)
      recompute_folds()
    end)
  end
end

---@package
---@param lnum integer|nil
---@return string
function M.foldexpr(lnum)
  lnum = lnum or vim.v.lnum
  local bufnr = api.nvim_get_current_buf()

  local parser = vim.F.npcall(vim.treesitter.get_parser, bufnr)
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

      on_bytes = function(_, _, start_row, _, _, old_row, _, _, new_row, _, _)
        on_bytes(bufnr, foldinfos[bufnr], start_row, old_row, new_row)
      end,

      on_detach = function()
        foldinfos[bufnr] = nil
      end,
    })
  end

  return foldinfos[bufnr].levels[lnum] or '0'
end

return M
