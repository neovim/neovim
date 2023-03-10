local api = vim.api

local M = {}

--- Memoizes a function based on the buffer tick of the provided bufnr.
--- The cache entry is cleared when the buffer is detached to avoid memory leaks.
---@generic F: function
---@param fn F fn to memoize, taking the bufnr as first argument
---@return F
local function memoize_by_changedtick(fn)
  ---@type table<integer,{result:any,last_tick:integer}>
  local cache = {}

  ---@param bufnr integer
  return function(bufnr, ...)
    local tick = api.nvim_buf_get_changedtick(bufnr)

    if cache[bufnr] then
      if cache[bufnr].last_tick == tick then
        return cache[bufnr].result
      end
    else
      local function detach_handler()
        cache[bufnr] = nil
      end

      -- Clean up logic only!
      api.nvim_buf_attach(bufnr, false, {
        on_detach = detach_handler,
        on_reload = detach_handler,
      })
    end

    cache[bufnr] = {
      result = fn(bufnr, ...),
      last_tick = tick,
    }

    return cache[bufnr].result
  end
end

---@param bufnr integer
---@param capture string
---@param query_name string
---@param callback fun(id: integer, node:TSNode, metadata: TSMetadata)
local function iter_matches_with_capture(bufnr, capture, query_name, callback)
  local parser = vim.treesitter.get_parser(bufnr)

  if not parser then
    return
  end

  parser:for_each_tree(function(tree, lang_tree)
    local lang = lang_tree:lang()
    local query = vim.treesitter.query.get_query(lang, query_name)
    if query then
      local root = tree:root()
      local start, _, stop = root:range()
      for _, match, metadata in query:iter_matches(root, bufnr, start, stop) do
        for id, node in pairs(match) do
          if query.captures[id] == capture then
            callback(id, node, metadata)
          end
        end
      end
    end
  end)
end

---@private
--- TODO(lewis6991): copied from languagetree.lua. Consolidate
---@param node TSNode
---@param id integer
---@param metadata TSMetadata
---@return Range
local function get_range_from_metadata(node, id, metadata)
  if metadata[id] and metadata[id].range then
    return metadata[id].range --[[@as Range]]
  end
  return { node:range() }
end

-- This is cached on buf tick to avoid computing that multiple times
-- Especially not for every line in the file when `zx` is hit
---@param bufnr integer
---@return table<integer,string>
local folds_levels = memoize_by_changedtick(function(bufnr)
  local max_fold_level = vim.wo.foldnestmax
  local function trim_level(level)
    if level > max_fold_level then
      return max_fold_level
    end
    return level
  end

  -- start..stop is an inclusive range
  local start_counts = {} ---@type table<integer,integer>
  local stop_counts = {} ---@type table<integer,integer>

  local prev_start = -1
  local prev_stop = -1

  local min_fold_lines = vim.wo.foldminlines

  iter_matches_with_capture(bufnr, 'fold', 'folds', function(id, node, metadata)
    local range = get_range_from_metadata(node, id, metadata)
    local start, stop, stop_col = range[1], range[3], range[4]

    if stop_col == 0 then
      stop = stop - 1
    end

    local fold_length = stop - start + 1

    -- Fold only multiline nodes that are not exactly the same as previously met folds
    -- Checking against just the previously found fold is sufficient if nodes
    -- are returned in preorder or postorder when traversing tree
    if fold_length > min_fold_lines and not (start == prev_start and stop == prev_stop) then
      start_counts[start] = (start_counts[start] or 0) + 1
      stop_counts[stop] = (stop_counts[stop] or 0) + 1
      prev_start = start
      prev_stop = stop
    end
  end)

  ---@type table<integer,string>
  local levels = {}
  local current_level = 0

  -- We now have the list of fold opening and closing, fill the gaps and mark where fold start
  for lnum = 0, api.nvim_buf_line_count(bufnr) do
    local last_trimmed_level = trim_level(current_level)
    current_level = current_level + (start_counts[lnum] or 0)
    local trimmed_level = trim_level(current_level)
    current_level = current_level - (stop_counts[lnum] or 0)

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

    levels[lnum + 1] = prefix .. tostring(trimmed_level)
  end

  return levels
end)

---@param lnum integer|nil
---@return string
function M.foldexpr(lnum)
  lnum = lnum or vim.v.lnum
  local bufnr = api.nvim_get_current_buf()

  ---@diagnostic disable-next-line:invisible
  if not vim.treesitter._has_parser(bufnr) or not lnum then
    return '0'
  end

  local levels = folds_levels(bufnr) or {}

  return levels[lnum] or '0'
end

return M
