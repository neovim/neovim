local api = vim.api

-- TODO(lewis6991): copied from languagetree.lua - consolidate
local function get_node_range(node, id, metadata)
  if metadata[id] and metadata[id].range then
    return metadata[id].range
  end
  return { node:range() }
end

---@param highlighter table TSHighlighter to use
---@param row integer Row to check
---@returns array of tuples (start_col, len, type) indicating positions in row
local function get_spell_marks(highlighter, row)
  local marks = {}

  highlighter.tree:for_each_tree(function(tstree, langtree)
    local hl_query = highlighter:get_query(langtree:lang())

    local spell_query = hl_query.query()

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

    for id, node, metadata in spell_query:iter_captures(root_node, bufnr, row, row + 1) do
      if spell_query.captures[id] == 'spell' then
        local range = get_node_range(node, id, metadata)
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

local function get_nav_target(bufnr, winid, forward)
  local highlighter = vim.treesitter.highlighter.active[bufnr]
  local lnum, col = unpack(api.nvim_win_get_cursor(winid))

  -- TODO(lewis6991): support 'wrapscan' (with message)
  if forward then
    for i = lnum, api.nvim_buf_line_count(bufnr) do
      local marks = get_spell_marks(highlighter, i - 1)
      for j = 1, #marks do
        local mcol = marks[j][1]
        if i ~= lnum or col < mcol then
          return { i, mcol }
        end
      end
    end
  else
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
end

local function nav(forward, fallback)
  return function()
    local bufnr = api.nvim_get_current_buf()
    local winid = api.nvim_get_current_win()

    if not enabled(winid, bufnr) then
      return fallback
    end

    local target = get_nav_target(bufnr, winid, forward)

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

if vim.fn.hasmapto(']s', 'n') == 0 then
  vim.keymap.set(
    'n',
    ']s',
    nav(true, ']s'),
    { expr = true, desc = 'vim.treesitter.spell.nav (forward)' }
  )
end

if vim.fn.hasmapto('[s', 'n') == 0 then
  vim.keymap.set(
    'n',
    '[s',
    nav(false, '[s'),
    { expr = true, desc = 'vim.treesitter.spell.nav (backward)' }
  )
end

-- TODO(lewis6991): implement ]S and [S

return M
