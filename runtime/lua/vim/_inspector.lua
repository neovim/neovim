--- @diagnostic disable:no-unknown

--- @class vim.inspect_pos.Opts
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
---
--- End row (0-based, inclusive) for range inspection. When specified together with `end_col`,
--- items overlapping the range from `(row, col)` to `(end_row, end_col)` are returned.
--- (default: `nil`, single position)
--- @field end_row? integer
---
--- End column (0-based, exclusive) for range inspection.
--- (default: `nil`, single position)
--- @field end_col? integer

--- @class vim.inspect_pos.Item
--- @field hl_group string highlight group name
--- @field hl_group_link string resolved highlight group (after following links)
--- @field row? integer start row (0-based)
--- @field col? integer start column (0-based)
--- @field end_row? integer end row (0-based, exclusive)
--- @field end_col? integer end column (0-based, exclusive)

--- @class vim.inspect_pos.TSItem : vim.inspect_pos.Item
--- @field capture string treesitter capture name
--- @field lang string parser language
--- @field metadata vim.treesitter.query.TSMetadata capture metadata
--- @field id integer capture id
--- @field pattern_id integer pattern id

--- @class vim.inspect_pos.ExtmarkItem : vim.inspect_pos.Item
--- @field id integer extmark id
--- @field ns_id integer namespace id
--- @field ns string namespace name
--- Note: `opts.hl_group_link` is deprecated; use the top-level `hl_group_link` field.
--- @field opts vim.api.keyset.extmark_details raw extmark details from |nvim_buf_get_extmarks()|.

--- @class vim.inspect_pos.Result
--- @inlinedoc
--- @field buffer integer buffer number
--- @field row integer queried start row (0-based)
--- @field col integer queried start column (0-based)
--- @field end_row? integer queried end row (only set for range queries)
--- @field end_col? integer queried end column (only set for range queries)
--- @field treesitter vim.inspect_pos.TSItem[]
--- @field syntax vim.inspect_pos.Item[]
--- @field extmarks vim.inspect_pos.ExtmarkItem[]
--- @field semantic_tokens vim.inspect_pos.ExtmarkItem[]

local defaults = {
  syntax = true,
  treesitter = true,
  extmarks = true,
  semantic_tokens = true,
}

--- Resolve highlight links and set `hl_group_link` on the item.
--- @param data { hl_group?: string, [string]: any }
--- @return vim.inspect_pos.Item
local function resolve_hl(data)
  if data.hl_group then
    local hlid = vim.api.nvim_get_hl_id_by_name(data.hl_group)
    local name = vim.fn.synIDattr(vim.fn.synIDtrans(hlid), 'name')
    data.hl_group_link = name
  end
  --- @diagnostic disable-next-line: return-type-mismatch
  return data
end

--- Collect syntax groups across all positions in a range (end_col is exclusive).
--- Contiguous positions with the same synstack are joined into single items.
--- @param bufnr integer
--- @param start_row integer start row (0-based)
--- @param start_col integer start column (0-based)
--- @param end_row integer end row (0-based)
--- @param end_col integer end column (0-based, exclusive)
--- @return vim.inspect_pos.Item[]
local function collect_syntax(bufnr, start_row, start_col, end_row, end_col)
  return vim._with({ buf = bufnr }, function()
    local items = {} --- @type vim.inspect_pos.Item[]
    local prev_stack = {} --- @type integer[]
    local open = {} --- @type vim.inspect_pos.Item[]
    for r = start_row, end_row do
      local line = vim.api.nvim_buf_get_lines(bufnr, r, r + 1, false)[1] or ''
      local c_start = r == start_row and start_col or 0
      local c_end = r == end_row and math.min(end_col, #line) or #line
      for c = c_start, math.max(c_end - 1, c_start) do
        local stack = vim.fn.synstack(r + 1, c + 1)
        if vim.deep_equal(stack, prev_stack) then
          -- Same stack as previous position: extend all open items.
          for _, item in ipairs(open) do
            item.end_row = r
            item.end_col = c + 1
          end
        else
          -- Stack changed: start new items.
          open = {}
          for _, i1 in ipairs(stack) do
            local item = resolve_hl({
              hl_group = vim.fn.synIDattr(i1, 'name'),
              row = r,
              col = c,
              end_row = r,
              end_col = c + 1,
            })
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
---single position. `end_col` is exclusive (past-the-end).
---
---@since 11
---@param bufnr? integer defaults to the current buffer
---@param row? integer row to inspect, 0-based. Defaults to the row of the current cursor
---@param col? integer col to inspect, 0-based. Defaults to the col of the current cursor
---@param opts? vim.inspect_pos.Opts
---@return vim.inspect_pos.Result
function vim.inspect_pos(bufnr, row, col, opts)
  opts = vim.tbl_deep_extend('force', defaults, opts or {})

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
  bufnr = vim._resolve_bufnr(bufnr)

  local end_row, end_col = opts.end_row, opts.end_col

  --- @type vim.inspect_pos.Result
  local results = {
    treesitter = {},
    syntax = {},
    extmarks = {},
    semantic_tokens = {},
    buffer = bufnr,
    row = row,
    col = col,
    end_row = end_row,
    end_col = end_col,
  }

  -- treesitter
  if opts.treesitter then
    for _, capture in
      ipairs(
        vim.treesitter.get_captures_in_range(
          bufnr,
          { row, col },
          { end_row or row, end_col or col + 1 }
        )
      )
    do
      --- @diagnostic disable-next-line: inject-field
      capture.hl_group = '@' .. capture.capture .. '.' .. capture.lang
      results.treesitter[#results.treesitter + 1] = resolve_hl(capture)
    end
  end

  -- syntax
  if opts.syntax and vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].syntax ~= '' then
    results.syntax = collect_syntax(bufnr, row, col, end_row or row, end_col or col + 1)
  end

  -- namespace id -> name map
  local nsmap = {} --- @type table<integer,string>
  for name, id in pairs(vim.api.nvim_get_namespaces()) do
    nsmap[id] = name
  end

  --- Convert an extmark tuple into a table
  --- @param extmark vim.api.keyset.get_extmark_item
  --- @return vim.inspect_pos.ExtmarkItem
  local function to_map(extmark)
    local details = assert(extmark[4])
    local hl_group_link --- @type string?
    if details.hl_group then
      local hlid = vim.api.nvim_get_hl_id_by_name(details.hl_group)
      hl_group_link = vim.fn.synIDattr(vim.fn.synIDtrans(hlid), 'name')
      -- COMPAT: inject hl_group_link into opts for backward compatibility.
      -- Deprecated: use the top-level hl_group_link field instead.
      details.hl_group_link = hl_group_link
    end
    return {
      id = extmark[1],
      row = extmark[2],
      col = extmark[3],
      end_row = details.end_row or extmark[2],
      end_col = details.end_col or extmark[3],
      hl_group = details.hl_group,
      hl_group_link = hl_group_link,
      opts = details,
      ns_id = details.ns_id,
      ns = nsmap[details.ns_id] or '',
    }
  end

  -- Extmarks: nvim_buf_get_extmarks bounds are inclusive.
  -- For range queries, convert our exclusive end_col to inclusive for the API.
  local extmarks0 = vim.api.nvim_buf_get_extmarks(
    bufnr,
    -1,
    { row, col },
    { end_row or row, end_col and math.max(end_col - 1, 0) or col },
    {
      details = true,
      overlap = true,
    }
  )
  --- @type vim.inspect_pos.ExtmarkItem[]
  local extmarks = vim.tbl_map(to_map, extmarks0)

  if not end_row and not end_col and opts.extmarks ~= 'all' then
    -- For single-position queries, exclude end_col and unpaired marks unless
    -- opts.extmarks == 'all' (a highlight is drawn until end_col - 1).
    extmarks = vim.tbl_filter(function(extmark)
      return row < extmark.end_row or col < extmark.end_col
    end, extmarks)
  end

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
---@param opts? vim.inspect_pos.Opts
function vim.show_pos(bufnr, row, col, opts)
  local items = vim.inspect_pos(bufnr, row, col, opts)

  local lines = { {} }

  local function append(str, hl)
    table.insert(lines[#lines], { str, hl })
  end

  local function nl()
    table.insert(lines, {})
  end

  local is_range = items.end_row ~= nil

  local function item(data, comment)
    append('  - ')
    append(data.hl_group, data.hl_group)
    append(' ')
    if data.hl_group ~= data.hl_group_link then
      append('links to ', 'MoreMsg')
      append(data.hl_group_link, data.hl_group_link)
      append('   ')
    end
    if is_range and data.row then
      append(
        string.format('[%d:%d - %d:%d]', data.row, data.col, data.end_row, data.end_col),
        'LineNr'
      )
      append('   ')
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
      if extmark.hl_group then
        item(extmark, extmark.ns)
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
    local pos_str
    if items.end_row then
      pos_str = items.row .. ',' .. items.col .. ' to ' .. items.end_row .. ',' .. items.end_col
    else
      pos_str = items.row .. ',' .. items.col
    end
    chunks = {
      {
        'No items found at position ' .. pos_str .. ' in buffer ' .. items.buffer,
      },
    }
  end
  vim.api.nvim_echo(chunks, false, { kind = 'list_cmd' })
end
