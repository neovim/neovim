--[[
TODO:
- support elseif/else
- support html / non-keywords
- add syntax fallback
]]

local M = {}

local ts = vim.treesitter

--- Jump to the start or end of a given node
--- @param node TSNode The node to jump to
--- @param start? boolean Jump to the start or end of the node
local function jump_to_node(node, start)
  start = vim.F.if_nil(start, true)
  local row, col
  if start then
    row, col = node:start()
  else
    row, col = node:end_()
    col = col - 1
  end
  vim.api.nvim_win_set_cursor(0, { row + 1, col })
end


--- @param keyword TSNode Anonymous node
--- @return boolean
local function cursor_on_keyword(keyword)
  local cursor_row, cursor_col = unpack(vim.api.nvim_win_get_cursor(0))
  return ts.is_in_node_range(keyword, cursor_row - 1, cursor_col)
end

--- TODO: elif/else not supported
--- @param current TSNode
--- @param backward? boolean Search backward for matching keyword
local function match_keyword(current, backward)
  -- unnamed (anonymous) nodes are keywords
  local keywords = vim.iter(current:iter_children()):filter(function(node)
    return not node:named()
  end)

  -- prev for backwards matching, first for wrapping last item
  local prev, first
  for keyword in keywords do
    if cursor_on_keyword(keyword) then
      if backward then
        -- if first item, wrap to last item
        jump_to_node(prev or keywords:last())
      else
        -- if last item, wrap to first item
        jump_to_node(keywords:next() or first)
      end
      return
    end
    first = vim.F.if_nil(first, keyword)
    prev = keyword
  end
end

--- @param current TSNode
--- @param backward? boolean Search backward for matching keyword
local function match_capture(current, target_capture, backward)
  print('not implemented')
end

--- @param current TSNode
local function match_punc(current)
  -- TODO: works, but variable names not clear
  local cursor = vim.api.nvim_win_get_cursor(0)
  local node_row, node_col, _ = current:start()
  local node_start = { node_row + 1, node_col }
  local at_start = vim.deep_equal(cursor, node_start)
  jump_to_node(current, not at_start)
end

function M.decide(backward)
  local node = ts.get_node()
  if not node then
    return
  end
  -- TODO: refactor for easier maintaining
  for _, capture in ipairs(ts.get_captures_at_cursor(0)) do
    -- TODO: if not on one of these, forward search line for punctuation
    if not capture then
      return
    elseif vim.startswith(capture, "keyword") then
      match_keyword(node, backward)
      return
    elseif vim.startswith(capture, "punctuation.bracket") or vim.startswith(capture, "tag.delimiter") then
      match_punc(node)
      return
    elseif vim.startswith(capture, "markup.heading") then
      match_capture(node, capture, backward)
      return
    end
  end
end

return M
