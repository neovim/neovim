--- @diagnostic disable:no-unknown

--- @class vim.inspect_pos.Opts
--- @inlinedoc
---
--- Include syntax based highlight groups.
--- (default: `true`)
--- @field syntax? boolean
---
--- Include treesitter based highlight groups.
--- (default: `true`)
--- @field treesitter? boolean
---
--- Include extmark highlights. When `all`, also include point marks and extmarks
--- without a `hl_group`.
--- (default: true)
--- @field extmarks? boolean|"all"
---
--- Include semantic token highlights.
--- (default: true)
--- @field semantic_tokens? boolean
---
--- End row (0-based) for range inspection. Must be specified together with `end_col`;
--- items overlapping the range from `(row, col)` to `(end_row, end_col)` are returned.
--- (default: `nil`, single position)
--- @field end_row? integer
---
--- End column (0-based, exclusive) for range inspection.
--- (default: `nil`, single position)
--- @field end_col? integer

--- @class vim.inspect_pos.Item
--- @field hl_group? string highlight group name, if any
--- @field hl_group_link? string resolved highlight group (after following links), if any
--- @field row integer start row (0-based)
--- @field col integer start byte column (0-based)
--- @field end_row integer end row (0-based)
--- @field end_col integer end byte column (0-based, exclusive)

--- @class vim.inspect_pos.SyntaxItem : vim.inspect_pos.Item
--- @field hl_group string highlight group name
--- @field hl_group_link string resolved highlight group (after following links)

--- @class vim.inspect_pos.TSItem : vim.treesitter.CaptureInfo
--- @field hl_group string highlight group name
--- @field hl_group_link string resolved highlight group (after following links)

--- `opts.hl_group_link` is deprecated; use the top-level `hl_group_link` field.
--- @class vim.inspect_pos.ExtmarkItem : vim.inspect_pos.Item
--- @field id integer extmark id
--- @field ns_id integer namespace id
--- @field ns string namespace name
--- @field opts vim.api.keyset.extmark_details & { hl_group_link?: string } raw extmark details from |nvim_buf_get_extmarks()|.

--- @class vim.inspect_pos.Result
--- @inlinedoc
--- @field buffer integer buffer number
--- @field row integer queried start row (0-based)
--- @field col integer queried start column (0-based)
--- @field end_row? integer queried end row (only set for range queries)
--- @field end_col? integer queried end column (only set for range queries)
--- @field treesitter vim.inspect_pos.TSItem[]
--- @field syntax vim.inspect_pos.SyntaxItem[]
--- @field extmarks vim.inspect_pos.ExtmarkItem[]
--- @field semantic_tokens vim.inspect_pos.ExtmarkItem[]

local defaults = {
  syntax = true,
  treesitter = true,
  extmarks = true,
  semantic_tokens = true,
}

--- @param hl_group string
--- @return string
local function resolve_hl(hl_group)
  local hlid = vim.api.nvim_get_hl_id_by_name(hl_group)
  return vim.fn.synIDattr(vim.fn.synIDtrans(hlid), 'name')
end

--- Collect syntax groups across all positions in a range (end_col is exclusive).
--- Contiguous positions with the same synstack are joined into single items.
--- @param buf integer
--- @param start_row integer start row (0-based)
--- @param start_col integer start column (0-based)
--- @param end_row? integer end row (0-based)
--- @param end_col? integer end column (0-based, exclusive)
--- @return vim.inspect_pos.SyntaxItem[]
local function collect_syntax(buf, start_row, start_col, end_row, end_col)
  return vim._with({ buf = buf }, function()
    local items = {} --- @type vim.inspect_pos.SyntaxItem[]
    local prev_stack = {} --- @type integer[]
    local open = {} --- @type vim.inspect_pos.SyntaxItem[]
    for r = start_row, end_row or start_row do
      local line = vim.api.nvim_buf_get_lines(buf, r, r + 1, false)[1] or ''
      local c_start = r == start_row and start_col or 0
      -- Include newlines before the exclusive end row, including on empty lines.
      -- Single-position inspection also queries syntax at or past the end of a line.
      local c_end = end_col and (r == end_row and math.min(end_col, #line) or #line + 1)
        or start_col + 1
      for c = c_start, c_end - 1 do
        local next_row, next_col = r, c + 1
        if end_row and c == #line then
          next_row, next_col = r + 1, 0
        end
        local stack = vim.fn.synstack(r + 1, c + 1)
        if vim.deep_equal(stack, prev_stack) then
          -- Same stack as previous position: extend all open items.
          for _, item in ipairs(open) do
            item.end_row = next_row
            item.end_col = next_col
          end
        else
          -- Stack changed: start new items.
          open = {}
          for _, i1 in ipairs(stack) do
            local hl_group = vim.fn.synIDattr(i1, 'name')
            --- @type vim.inspect_pos.SyntaxItem
            local item = {
              hl_group = hl_group,
              hl_group_link = resolve_hl(hl_group),
              row = r,
              col = c,
              end_row = next_row,
              end_col = next_col,
            }
            open[#open + 1] = item
            items[#items + 1] = item
          end
          prev_stack = stack
        end
      end
    end
    return items
  end)
end

---Get all the items at a given buffer position.
---
---Can also be pretty-printed with `:Inspect!`. [:Inspect!]()
---
---When `end_row` and `end_col` are given in the `opts` table, items overlapping the
---range `(row, col)` to `(end_row, end_col)` are returned instead of only those at a
---single position. `end_col` is exclusive (past-the-end). Empty ranges return no items.
---
---@since 11
---@param buf? integer defaults to the current buffer
---@param row? integer row to inspect, 0-based. Defaults to the row of the current cursor
---@param col? integer col to inspect, 0-based. Defaults to the col of the current cursor
---@param opts? vim.inspect_pos.Opts
---@return vim.inspect_pos.Result Items are in traversal order.
function vim.inspect_pos(buf, row, col, opts)
  opts = vim.tbl_deep_extend('force', defaults, opts or {})

  buf = buf or 0
  if row == nil or col == nil then
    -- get the row/col from the first window displaying the buffer
    local win = buf == 0 and vim.api.nvim_get_current_win() or vim.fn.bufwinid(buf)
    if win == -1 then
      error('row/col is required for buffers not visible in a window')
    end
    local cursor = vim.api.nvim_win_get_cursor(win)
    row, col = cursor[1] - 1, cursor[2]
  end
  buf = vim._resolve_bufnr(buf)
  ---@cast row integer
  ---@cast col integer

  local end_row, end_col = opts.end_row, opts.end_col
  assert((end_row == nil) == (end_col == nil), 'end_row and end_col must be specified together')

  --- @type vim.inspect_pos.Result
  local results = {
    treesitter = {},
    syntax = {},
    extmarks = {},
    semantic_tokens = {},
    buffer = buf,
    row = row,
    col = col,
    end_row = end_row,
    end_col = end_col,
  }

  if end_row and (end_row < row or end_row == row and end_col <= col) then
    return results
  end

  -- treesitter
  if opts.treesitter then
    results.treesitter =
      vim.treesitter.get_captures(buf, { row, col }, end_row and { end_row, end_col } or nil) --[[@as vim.inspect_pos.TSItem[] ]]
    for _, item in ipairs(results.treesitter) do
      item.hl_group = '@' .. item.capture .. '.' .. item.lang
      item.hl_group_link = resolve_hl(item.hl_group)
    end
  end

  -- syntax
  if opts.syntax and vim.api.nvim_buf_is_valid(buf) then
    results.syntax = collect_syntax(buf, row, col, end_row, end_col)
  end

  if not opts.extmarks and not opts.semantic_tokens then
    return results
  end

  -- namespace id -> name map
  local nsmap = {} --- @type table<integer,string>
  for name, id in pairs(vim.api.nvim_get_namespaces()) do
    nsmap[id] = name
  end

  --- Convert an extmark tuple into a table
  --- @param extmark vim.api.keyset.get_extmark_item
  --- @return vim.inspect_pos.ExtmarkItem
  local function extmark_to_item(extmark)
    -- Keep opts.hl_group_link for compatibility with single-position callers.
    local details = assert(extmark[4]) --- @type vim.api.keyset.extmark_details & { hl_group_link?: string }
    if details.hl_group then
      details.hl_group_link = resolve_hl(details.hl_group)
    end
    return {
      id = extmark[1],
      row = extmark[2],
      col = extmark[3],
      end_row = details.end_row or extmark[2],
      end_col = details.end_col or extmark[3],
      hl_group = details.hl_group,
      hl_group_link = details.hl_group_link,
      opts = details,
      ns_id = details.ns_id,
      ns = nsmap[details.ns_id] or '',
    }
  end

  --- Check whether the extmark overlaps the inspected position or range.
  --- Point marks are included only when opts.extmarks == 'all'.
  --- @param extmark vim.inspect_pos.ExtmarkItem
  --- @return boolean
  local function include_extmark(extmark)
    if end_row and (extmark.row > end_row or extmark.row == end_row and extmark.col >= end_col) then
      return false
    end
    if opts.extmarks == 'all' then
      -- Include point marks inside a range, and preserve the single-position behavior.
      if not end_row or extmark.row > row or extmark.row == row and extmark.col >= col then
        return true
      end
    elseif extmark.row == extmark.end_row and extmark.col == extmark.end_col then
      return false
    end
    return row < extmark.end_row or row == extmark.end_row and col < extmark.end_col
  end

  -- Extmark API bounds are inclusive. Filter both boundaries, including
  -- ends at column zero, which cannot be converted by subtracting one column.
  local marks = vim.api.nvim_buf_get_extmarks(
    buf,
    -1,
    { row, col },
    { end_row or row, end_col or col },
    {
      details = true,
      overlap = true,
    }
  )
  local extmarks = vim.tbl_filter(include_extmark, vim.tbl_map(extmark_to_item, marks))

  if opts.semantic_tokens then
    results.semantic_tokens = vim.tbl_filter(function(extmark)
      return extmark.ns:find('nvim.lsp.semantic_tokens') == 1
    end, extmarks)
  end

  if opts.extmarks then
    results.extmarks = vim.tbl_filter(function(extmark)
      return extmark.ns:find('nvim.lsp.semantic_tokens') ~= 1
        and (opts.extmarks == 'all' or extmark.hl_group ~= nil)
    end, extmarks)
  end

  return results
end

---Show all the items at a given buffer position.
---
---Can also be shown with `:Inspect`. [:Inspect]()
---
---`:Inspect` accepts an Ex range, inspecting all the addressed lines, including
---when invoked from Visual mode. Use `opts.end_row` and `opts.end_col` for a byte range.
---
---See also |:marks| to list all extmarks.
---
---Example: To bind this function to the vim-scriptease
---inspired `zS` in Normal mode:
---
---```lua
---vim.keymap.set('n', 'zS', vim.show_pos)
---```
---
---@since 11
---@param buf? integer defaults to the current buffer
---@param row? integer row to inspect, 0-based. Defaults to the row of the current cursor
---@param col? integer col to inspect, 0-based. Defaults to the col of the current cursor
---@param opts? vim.inspect_pos.Opts
function vim.show_pos(buf, row, col, opts)
  local items = vim.inspect_pos(buf, row, col, opts)

  local lines = { {} }

  ---@param str string
  ---@param hl? string
  local function append(str, hl)
    table.insert(lines[#lines], { str, hl })
  end

  local function nl()
    table.insert(lines, {})
  end

  local is_range = items.end_row ~= nil

  --- @param data vim.inspect_pos.Item
  --- @param comment? string
  local function item(data, comment)
    append('  - ')
    if data.hl_group then
      assert(data.hl_group_link)
      append(data.hl_group, data.hl_group)
      append(' ')
      if data.hl_group ~= data.hl_group_link then
        append('links to ', 'MoreMsg')
        append(data.hl_group_link, data.hl_group_link)
        append('   ')
      end
    end
    if is_range then
      append(('[%d:%d - %d:%d]'):format(data.row, data.col, data.end_row, data.end_col), 'LineNr')
      append('   ')
    end
    if comment then
      append(comment, 'Dimmed')
    end
    nl()
  end

  -- treesitter
  if #items.treesitter > 0 then
    append('Treesitter', 'Title')
    nl()
    for _, capture in ipairs(items.treesitter) do
      item(
        capture,
        string.format(
          'priority: %d   language: %s',
          capture.metadata.priority
            or (capture.metadata[capture.id] and capture.metadata[capture.id].priority)
            or vim.hl.priorities.treesitter,
          capture.lang
        )
      )
    end
    nl()
  end

  -- semantic tokens
  if #items.semantic_tokens > 0 then
    append('Semantic Tokens', 'Title')
    nl()
    local sorted_marks = vim.fn.sort(items.semantic_tokens, function(left, right)
      local left_first = left.opts.priority < right.opts.priority
        or left.opts.priority == right.opts.priority and left.hl_group < right.hl_group
      return left_first and -1 or 1
    end)
    for _, extmark in ipairs(sorted_marks) do
      item(extmark, 'priority: ' .. extmark.opts.priority)
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
      item(extmark, extmark.ns)
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
    local pos_str
    if items.end_row then
      pos_str = items.row .. ',' .. items.col .. ' to ' .. items.end_row .. ',' .. items.end_col
    else
      pos_str = items.row .. ',' .. items.col
    end
    chunks = {
      {
        ('No items found at position %s in buffer %d'):format(pos_str, items.buffer),
      },
    }
  end
  vim.api.nvim_echo(chunks, false, { kind = 'list_cmd' })
end
