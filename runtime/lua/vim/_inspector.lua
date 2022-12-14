---@class InspectorFilter
---@field syntax boolean include syntax based highlight groups (defaults to true)
---@field treesitter boolean include treesitter based highlight groups (defaults to true)
---@field extmarks boolean|"all" include extmarks. When `all`, then extmarks without a `hl_group` will also be included (defaults to true)
---@field semantic_tokens boolean include semantic tokens (defaults to true)
local defaults = {
  syntax = true,
  treesitter = true,
  extmarks = true,
  semantic_tokens = true,
}

---Get all the items at a given buffer position.
---
---Can also be pretty-printed with `:Inspect!`. *:Inspect!*
---
---@param bufnr? number defaults to the current buffer
---@param row? number row to inspect, 0-based. Defaults to the row of the current cursor
---@param col? number col to inspect, 0-based. Defaults to the col of the current cursor
---@param filter? InspectorFilter (table|nil) a table with key-value pairs to filter the items
---               - syntax (boolean): include syntax based highlight groups (defaults to true)
---               - treesitter (boolean): include treesitter based highlight groups (defaults to true)
---               - extmarks (boolean|"all"): include extmarks. When `all`, then extmarks without a `hl_group` will also be included (defaults to true)
---               - semantic_tokens (boolean): include semantic tokens (defaults to true)
---@return {treesitter:table,syntax:table,extmarks:table,semantic_tokens:table,buffer:number,col:number,row:number} (table) a table with the following key-value pairs. Items are in "traversal order":
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
    treesitter = {},
    syntax = {},
    extmarks = {},
    semantic_tokens = {},
    buffer = bufnr,
    row = row,
    col = col,
  }

  -- resolve hl links
  ---@private
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
      capture.hl_group = '@' .. capture.capture
      table.insert(results.treesitter, resolve_hl(capture))
    end
  end

  -- syntax
  if filter.syntax then
    for _, i1 in ipairs(vim.fn.synstack(row + 1, col + 1)) do
      table.insert(results.syntax, resolve_hl({ hl_group = vim.fn.synIDattr(i1, 'name') }))
    end
  end

  -- semantic tokens
  if filter.semantic_tokens then
    for _, token in ipairs(vim.lsp.semantic_tokens.get_at_pos(bufnr, row, col) or {}) do
      token.hl_groups = {
        type = resolve_hl({ hl_group = '@' .. token.type }),
        modifiers = vim.tbl_map(function(modifier)
          return resolve_hl({ hl_group = '@' .. modifier })
        end, token.modifiers or {}),
      }
      table.insert(results.semantic_tokens, token)
    end
  end

  -- extmarks
  if filter.extmarks then
    for ns, nsid in pairs(vim.api.nvim_get_namespaces()) do
      if ns:find('vim_lsp_semantic_tokens') ~= 1 then
        local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, nsid, 0, -1, { details = true })
        for _, extmark in ipairs(extmarks) do
          extmark = {
            ns_id = nsid,
            ns = ns,
            id = extmark[1],
            row = extmark[2],
            col = extmark[3],
            opts = resolve_hl(extmark[4]),
          }
          local end_row = extmark.opts.end_row or extmark.row -- inclusive
          local end_col = extmark.opts.end_col or (extmark.col + 1) -- exclusive
          if
            (filter.extmarks == 'all' or extmark.opts.hl_group) -- filter hl_group
            and (row >= extmark.row and row <= end_row) -- within the rows of the extmark
            and (row > extmark.row or col >= extmark.col) -- either not the first row, or in range of the col
            and (row < end_row or col < end_col) -- either not in the last row or in range of the col
          then
            table.insert(results.extmarks, extmark)
          end
        end
      end
    end
  end
  return results
end

---Show all the items at a given buffer position.
---
---Can also be shown with `:Inspect`. *:Inspect*
---
---@param bufnr? number defaults to the current buffer
---@param row? number row to inspect, 0-based. Defaults to the row of the current cursor
---@param col? number col to inspect, 0-based. Defaults to the col of the current cursor
---@param filter? InspectorFilter (table|nil) see |vim.inspect_pos()|
function vim.show_pos(bufnr, row, col, filter)
  local items = vim.inspect_pos(bufnr, row, col, filter)

  local lines = { {} }

  ---@private
  local function append(str, hl)
    table.insert(lines[#lines], { str, hl })
  end

  ---@private
  local function nl()
    table.insert(lines, {})
  end

  ---@private
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

  if #items.semantic_tokens > 0 then
    append('Semantic Tokens', 'Title')
    nl()
    for _, token in ipairs(items.semantic_tokens) do
      local client = vim.lsp.get_client_by_id(token.client_id)
      client = client and (' (' .. client.name .. ')') or ''
      item(token.hl_groups.type, 'type' .. client)
      for _, modifier in ipairs(token.hl_groups.modifiers) do
        item(modifier, 'modifier' .. client)
      end
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
