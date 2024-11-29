--- @class vim._inspector.Filter
--- @inlinedoc
---
--- Include syntax based highlight groups.
--- (default: `true`)
--- @field syntax boolean
---
--- Include treesitter based highlight groups.
--- (default: `true`)
--- @field treesitter boolean
---
--- Include extmarks. When `all`, then extmarks without a `hl_group` will also be included.
--- (default: true)
--- @field extmarks boolean|"all"
---
--- Include semantic token highlights.
--- (default: true)
--- @field semantic_tokens boolean
local defaults = {
  syntax = true,
  treesitter = true,
  extmarks = true,
  semantic_tokens = true,
}

---Get all the items at a given buffer position.
---
---Can also be pretty-printed with `:Inspect!`. [:Inspect!]()
---
---@since 11
---@param bufnr? integer defaults to the current buffer
---@param row? integer row to inspect, 0-based. Defaults to the row of the current cursor
---@param col? integer col to inspect, 0-based. Defaults to the col of the current cursor
---@param filter? vim._inspector.Filter Table with key-value pairs to filter the items
---@return {treesitter:table,syntax:table,extmarks:table,semantic_tokens:table,buffer:integer,col:integer,row:integer} (table) a table with the following key-value pairs. Items are in "traversal order":
---               - treesitter: a list of treesitter captures
---               - syntax: a list of syntax groups
---               - semantic_tokens: a list of semantic tokens
---               - extmarks: a list of extmarks
---               - buffer: the buffer used to get the items
---               - row: the row used to get the items
---               - col: the col used to get the items
function vim.inspect_pos(bufnr, row, col, filter)
  filter = vim.tbl_deep_extend('force', defaults, filter or {})

  bufnr = bufnr or 0
  if row == nil or col == nil then
    -- get the row/col from the first window displaying the buffer
    local win = bufnr == 0 and vim.api.nvim_get_current_win() or vim.fn.bufwinid(bufnr)
    if win == -1 then
      error('row/col is required for buffers not visible in a window')
    end
    local cursor = vim.api.nvim_win_get_cursor(win)
    row, col = cursor[1] - 1, cursor[2]
  end
  bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr

  local results = {
    treesitter = {}, --- @type table[]
    syntax = {}, --- @type table[]
    extmarks = {},
    semantic_tokens = {},
    buffer = bufnr,
    row = row,
    col = col,
  }

  -- resolve hl links
  local function resolve_hl(data)
    if data.hl_group then
      local hlid = vim.api.nvim_get_hl_id_by_name(data.hl_group)
      local name = vim.fn.synIDattr(vim.fn.synIDtrans(hlid), 'name')
      data.hl_group_link = name
    end
    return data
  end

  -- treesitter
  if filter.treesitter then
    for _, capture in pairs(vim.treesitter.get_captures_at_pos(bufnr, row, col)) do
      capture.hl_group = '@' .. capture.capture .. '.' .. capture.lang
      results.treesitter[#results.treesitter + 1] = resolve_hl(capture)
    end
  end

  -- syntax
  if filter.syntax and vim.api.nvim_buf_is_valid(bufnr) then
    vim._with({ buf = bufnr }, function()
      for _, i1 in ipairs(vim.fn.synstack(row + 1, col + 1)) do
        results.syntax[#results.syntax + 1] =
          resolve_hl({ hl_group = vim.fn.synIDattr(i1, 'name') })
      end
    end)
  end

  -- namespace id -> name map
  local nsmap = {} --- @type table<integer,string>
  for name, id in pairs(vim.api.nvim_get_namespaces()) do
    nsmap[id] = name
  end

  --- Convert an extmark tuple into a table
  local function to_map(extmark)
    extmark = {
      id = extmark[1],
      row = extmark[2],
      col = extmark[3],
      opts = resolve_hl(extmark[4]),
    }
    extmark.ns_id = extmark.opts.ns_id
    extmark.ns = nsmap[extmark.ns_id] or ''
    extmark.end_row = extmark.opts.end_row or extmark.row -- inclusive
    extmark.end_col = extmark.opts.end_col or (extmark.col + 1) -- exclusive
    return extmark
  end

  --- Check if an extmark overlaps this position
  local function is_here(extmark)
    return (row >= extmark.row and row <= extmark.end_row) -- within the rows of the extmark
      and (row > extmark.row or col >= extmark.col) -- either not the first row, or in range of the col
      and (row < extmark.end_row or col < extmark.end_col) -- either not in the last row or in range of the col
  end

  -- all extmarks at this position
  local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, -1, 0, -1, { details = true })
  extmarks = vim.tbl_map(to_map, extmarks)
  extmarks = vim.tbl_filter(is_here, extmarks)

  if filter.semantic_tokens then
    results.semantic_tokens = vim.tbl_filter(function(extmark)
      return extmark.ns:find('vim_lsp_semantic_tokens') == 1
    end, extmarks)
  end

  if filter.extmarks then
    results.extmarks = vim.tbl_filter(function(extmark)
      return extmark.ns:find('vim_lsp_semantic_tokens') ~= 1
        and (filter.extmarks == 'all' or extmark.opts.hl_group)
    end, extmarks)
  end

  return results
end

---Show all the items at a given buffer position.
---
---Can also be shown with `:Inspect`. [:Inspect]()
---
---Example: To bind this function to the vim-scriptease
---inspired `zS` in Normal mode:
---
---```lua
---vim.keymap.set('n', 'zS', vim.show_pos)
---```
---
---@since 11
---@param bufnr? integer defaults to the current buffer
---@param row? integer row to inspect, 0-based. Defaults to the row of the current cursor
---@param col? integer col to inspect, 0-based. Defaults to the col of the current cursor
---@param filter? vim._inspector.Filter
function vim.show_pos(bufnr, row, col, filter)
  local items = vim.inspect_pos(bufnr, row, col, filter)

  local lines = { {} }

  local function append(str, hl)
    table.insert(lines[#lines], { str, hl })
  end

  local function nl()
    table.insert(lines, {})
  end

  local function item(data, comment)
    append('  - ')
    append(data.hl_group, data.hl_group)
    append(' ')
    if data.hl_group ~= data.hl_group_link then
      append('links to ', 'MoreMsg')
      append(data.hl_group_link, data.hl_group_link)
      append(' ')
    end
    if comment then
      append(comment, 'Comment')
    end
    nl()
  end

  -- treesitter
  if #items.treesitter > 0 then
    append('Treesitter', 'Title')
    nl()
    for _, capture in ipairs(items.treesitter) do
      item(capture, capture.lang)
    end
    nl()
  end

  -- semantic tokens
  if #items.semantic_tokens > 0 then
    append('Semantic Tokens', 'Title')
    nl()
    local sorted_marks = vim.fn.sort(items.semantic_tokens, function(left, right)
      local left_first = left.opts.priority < right.opts.priority
        or left.opts.priority == right.opts.priority and left.opts.hl_group < right.opts.hl_group
      return left_first and -1 or 1
    end)
    for _, extmark in ipairs(sorted_marks) do
      item(extmark.opts, 'priority: ' .. extmark.opts.priority)
    end
    nl()
  end

  -- syntax
  if #items.syntax > 0 then
    append('Syntax', 'Title')
    nl()
    for _, syn in ipairs(items.syntax) do
      item(syn)
    end
    nl()
  end

  -- extmarks
  if #items.extmarks > 0 then
    append('Extmarks', 'Title')
    nl()
    for _, extmark in ipairs(items.extmarks) do
      if extmark.opts.hl_group then
        item(extmark.opts, extmark.ns)
      else
        append('  - ')
        append(extmark.ns, 'Comment')
        nl()
      end
    end
    nl()
  end

  if #lines[#lines] == 0 then
    table.remove(lines)
  end

  local chunks = {}
  for _, line in ipairs(lines) do
    vim.list_extend(chunks, line)
    table.insert(chunks, { '\n' })
  end
  if #chunks == 0 then
    chunks = {
      {
        'No items found at position '
          .. items.row
          .. ','
          .. items.col
          .. ' in buffer '
          .. items.buffer,
      },
    }
  end
  vim.api.nvim_echo(chunks, false, {})
end
