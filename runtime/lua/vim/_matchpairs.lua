local M = {}

local ns = vim.api.nvim_create_namespace('nvim_matchpairs')

local ts = vim.treesitter
local api = vim.api

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
  api.nvim_win_set_cursor(0, { row + 1, col })
end


--- @param keyword TSNode Anonymous node
--- @return boolean
local function cursor_on_keyword(keyword)
  local cursor_row, cursor_col = unpack(api.nvim_win_get_cursor(0))
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
  local cursor = api.nvim_win_get_cursor(0)
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
    elseif vim.startswith(capture, 'keyword') then
      match_keyword(node, backward)
      return
    elseif vim.startswith(capture, 'punctuation.bracket') or vim.startswith(capture, 'tag.delimiter') then
      match_punc(node)
      return
    elseif vim.startswith(capture, 'markup.heading') then
      match_capture(node, capture, backward)
      return
    end
  end
end

local function norm_cursor_pos()
  local row, col = unpack(api.nvim_win_get_cursor(0))
  return { row - 1, col }
end

local function cursor_char()
  local r, c = unpack(norm_cursor_pos())
  return api.nvim_buf_get_text(0, r, c, r, c + 1, {})[1]
end

local function searchpair(left, right, forward)
  forward = vim.F.if_nil(forward, true)
  local dir = forward and '' or 'b'
  local row, col = unpack(vim.fn.searchpairpos(
    '\\M' .. left, -- :h \M
    '',
    '\\M' .. right,
    'nW' .. dir
  ))
  if row > 0 and col > 0 then
    return { row - 1, col - 1 }
  end
end


local function syntax_pairs()
  local char = cursor_char()
  for pair in vim.gsplit(vim.o.matchpairs, ',', { trimempty = true }) do
    -- TODO: also recognizes ':'. Rewrite.
    local idx = pair:find(char, 1, true)
    if idx ~= nil then
      local left, right = unpack(vim.split(pair, ':'))
      local forward = idx == 1 -- "a:b", from a forwards, b backwards
      local match = searchpair(left, right, forward)
      if match then
        return { norm_cursor_pos(), match }
      end
    end
  end
end

local function ts_pairs()
  local node = ts.get_node()
  if node then
    for _, capture in ipairs(ts.get_captures_at_cursor(0)) do
      if vim.startswith(capture, 'punctuation.bracket') then
        -- TODO: pairs[1] not working, go to first anon child not start of node
        local open_row, open_col = node:start()
        local close_row, close_col = node:end_()
        return { { open_row, open_col }, { close_row, close_col - 1 } }
      end
    end
  end
end

local function higlight_bracket(pos)
  local row, col = unpack(pos)
  api.nvim_buf_add_highlight(0, ns, 'MatchParen', row, col, col + 1)
end

-- TODO: insert mode: also when cursor is after bracket
function M.highlight()
  -- TODO: for development
  vim.cmd [[NoMatchParen]]
  api.nvim_set_hl(0, 'MatchParen', { bg = 'Red', fg = 'Yellow' })

  api.nvim_buf_clear_namespace(0, ns, 0, -1)

  local pairs = vim.F.if_nil(ts_pairs(), syntax_pairs())
  if pairs then
    higlight_bracket(pairs[1])
    higlight_bracket(pairs[2])
  end
end

return M
