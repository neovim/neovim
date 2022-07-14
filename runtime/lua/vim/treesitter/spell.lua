local api = vim.api
local query = require('vim.treesitter.query')

-- TODO(lewis6991): copied from languagetree.lua - consolidate
local function get_node_range(node, id, metadata)
  if metadata[id] and metadata[id].range then
    return metadata[id].range
  end
  return { node:range() }
end

local function get_query(lang, default)
  -- Use the spell query if there is one available otherwise just
  -- spellcheck comments.
  local lang_query = query.get_query(lang, 'spell')

  if lang_query then
    return lang_query
  end

  -- First fallback is to use the comment nodes, if defined
  local ok, ret = pcall(query.parse_query, lang, '(comment)  @spell')
  if ok then
    return ret
  end

  -- Second fallback is to use comments from the highlight captures
  return default
end

local SPELL_CAPTURES = { 'spell', 'comment' }

local function spell_check_node(bufnr, id, spell_query, range, row, marks)
  if not vim.tbl_contains(SPELL_CAPTURES, spell_query.captures[id]) then
    return
  end

  local start_row, start_col, end_row, end_col = unpack(range)
  start_col = row == start_row and start_col or 0
  local sub_end_col = row == end_row and end_col + 1 or -1

  local line = api.nvim_buf_get_lines(bufnr, row, row + 1, true)[1]
  local l = line:sub(start_col + 1, sub_end_col)

  for _, r in ipairs(vim.spell.check(l)) do
    local word, type, col = unpack(r)
    marks[#marks + 1] = { start_col + col - 1, #word, type }
  end
end

---@param highlighter table TSHighlighter to use
---@param row integer Row to check
---@param reuse_iter? boolean Use iterator from highlighter
---@returns array of tuples (start_col, len, type) indicating positions in row
local function get_spell_marks(highlighter, row, reuse_iter)
  local marks = {}

  highlighter.tree:for_each_tree(function(tstree, langtree)
    local hl_query = highlighter:get_query(langtree:lang())

    if hl_query._spell_query == nil then
      -- Make sure we set _spell_query to non-nil in order to avoid constantly trying to get the
      -- query if it fails the first time.
      hl_query._spell_query = get_query(langtree:lang(), hl_query:query()) or false
    end

    local spell_query = hl_query._spell_query

    if not spell_query then
      return
    end

    local root_node = tstree:root()

    local root_start_row, _, root_end_row, _ = root_node:range()

    -- Only worry about trees within the line range
    if root_start_row > row or root_end_row < row then
      return
    end

    local bufnr = highlighter.bufnr

    if not reuse_iter then
      for id, node, metadata in spell_query:iter_captures(root_node, bufnr, row, row + 1) do
        local range = get_node_range(node, id, metadata)
        spell_check_node(bufnr, id, spell_query, range, row, marks)
      end
    else
      local state = highlighter:get_highlight_state(tstree)

      if state.spell_iter == nil or state.spell_next_row < row then
        state.spell_iter = spell_query:iter_captures(root_node, bufnr, row, root_end_row + 1)
      end

      while row >= state.spell_next_row do
        local id, node, metadata = state.spell_iter()

        if id == nil then
          break
        end

        local range = get_node_range(node, id, metadata)
        spell_check_node(bufnr, id, spell_query, range, row, marks)

        local start_row = range[1]
        if start_row > row then
          state.spell_next_row = start_row
        end
      end
    end
  end)

  return marks
end

local function enabled(winid, bufnr)
  if not vim.treesitter.highlighter.active[bufnr] then
    return false
  end
  return vim.wo[winid].spell
end

local function get_nav_target_forward(bufnr, lnum, col)
  local highlighter = vim.treesitter.highlighter.active[bufnr]

  -- TODO(lewis6991): support 'wrapscan' (with message)
  for i = lnum, api.nvim_buf_line_count(bufnr) do
    local marks = get_spell_marks(highlighter, i - 1)
    for j = 1, #marks do
      local mcol = marks[j][1]
      if i ~= lnum or col < mcol then
        return { i, mcol }
      end
    end
  end
end

local function get_nav_target_backward(bufnr, lnum, col)
  local highlighter = vim.treesitter.highlighter.active[bufnr]

  -- TODO(lewis6991): support 'wrapscan' (with message)
  for i = lnum, 1, -1 do
    local marks = get_spell_marks(highlighter, i - 1)
    for j = #marks, 1, -1 do
      local mcol = marks[j][1]
      if i ~= lnum or col > mcol then
        return { i, mcol }
      end
    end
  end
end

local function nav(backward, fallback)
  return function()
    local bufnr = api.nvim_get_current_buf()
    local winid = api.nvim_get_current_win()

    if not enabled(winid, bufnr) then
      return fallback
    end

    local lnum, col = unpack(api.nvim_win_get_cursor(winid))
    local get_nav_target = backward and get_nav_target_backward or get_nav_target_forward
    local target = get_nav_target(bufnr, lnum, col)

    if target then
      vim.schedule(function()
        vim.cmd({ cmd = 'normal', bang = true, args = { "m'" } }) -- add current cursor position to the jump list
        api.nvim_win_set_cursor(winid, target)
      end)
      return '<Ignore>'
    end
  end
end

local M = {}

function M.on_win(winid, bufnr)
  if not enabled(winid, bufnr) then
    return
  end

  -- HACK ALERT: To prevent the internal spellchecker from spellchecking, we
  -- need to define a 'Spell' syntax group which contains nothing.
  api.nvim_win_call(winid, function()
    if vim.fn.has('syntax_items') == 0 then
      vim.cmd({ cmd = 'syntax', args = { 'cluster', 'Spell', 'contains=NONE' } })
    end
  end)
end

local ns = api.nvim_create_namespace('treesitter/spell')

local HIGHLIGHTS = {
  bad = 'SpellBad',
  caps = 'SpellCap',
  rare = 'SpellRare',
  ['local'] = 'SpellLocal',
}

function M.on_line(highlighter, winid, bufnr, row)
  if not enabled(winid, bufnr) then
    return
  end

  local cur_lnum, cur_col = unpack(api.nvim_win_get_cursor(winid))

  for _, mark in ipairs(get_spell_marks(highlighter, row, true)) do
    local col, len, type = unpack(mark)

    if cur_lnum - 1 == row and col <= cur_col and col + len >= cur_col then
      if api.nvim_get_mode().mode == 'i' then
        -- Don't highlight current word
        return
      end
    end

    api.nvim_buf_set_extmark(bufnr, ns, row, col, {
      end_line = row,
      end_col = col + len,
      hl_group = HIGHLIGHTS[type],
      ephemeral = true,
    })
  end
end

if vim.fn.hasmapto(']s', 'n') == 0 then
  vim.keymap.set(
    'n',
    ']s',
    nav(false, ']s'),
    { expr = true, desc = 'vim.treesitter.spell.nav (forward)' }
  )
end

if vim.fn.hasmapto('[s', 'n') == 0 then
  vim.keymap.set(
    'n',
    '[s',
    nav(true, '[s'),
    { expr = true, desc = 'vim.treesitter.spell.nav (backward)' }
  )
end

-- TODO(lewis6991): implement ]S and [S

return M
