local function binary_find(stack, priority, subpriority)
  if not stack[1] then
    return 1
  end

  local a = 1
  local b = #stack + 1

  while a ~= b do
    if
      stack[math.floor((b - a) / 2) + a].priority < priority
      or (
        stack[math.floor((b - a) / 2) + a].priority == priority
        and stack[math.floor((b - a) / 2) + a].subpriority < subpriority
      )
    then
      b = math.floor((b - a) / 2) + a
    else
      a = math.floor((b - a) / 2) + a + 1
    end
  end

  return a
end

return function(cmdline)
  -- The newline is required to ensure that the cmdline is parsed correctly
  local parser = vim.treesitter.get_string_parser(cmdline .. '\n', 'vim')
  parser:parse(true)

  local highlights = vim.treesitter._get_highlight(parser)
  ---@type {hl_group: string, range: [number, number], priority: number, subpriority: number, type: 'start' | 'end'}[]
  local positions = {}

  for _, hl in ipairs(highlights) do
    local start_row, start_col, end_row, end_col = vim.treesitter._range.unpack4(hl.range)

    if end_row > 0 then
      end_col = #cmdline
    end

    table.insert(positions, {
      hl_group = hl.hl_group,
      range = { start_row, start_col },
      priority = hl.priority,
      subpriority = #positions,
      type = 'start',
    })

    table.insert(positions, {
      hl_group = hl.hl_group,
      range = { end_row, end_col },
      priority = hl.priority,
      subpriority = #positions - 1,
      type = 'end',
    })
  end

  table.sort(positions, function(a, b)
    return a.range[1] < b.range[1]
      or (a.range[1] == b.range[1] and a.range[2] < b.range[2])
      or (
        a.range[1] == b.range[1]
        and a.range[2] == b.range[2]
        and a.type == 'start'
        and b.type == 'end'
      )
  end)

  local result = {}
  ---@type {hl_group: string, range: [number, number], priority: number, subpriority: number, type: 'start' | 'end'}[]
  local stack = {}
  local prev_pos_range = nil

  for _, pos in ipairs(positions) do
    if
      prev_pos_range
      and not (prev_pos_range[1] == pos.range[1] and prev_pos_range[2] == pos.range[2])
    then
      for _, v in ipairs(stack) do
        if
          not vim.tbl_isempty(vim.api.nvim_get_hl(0, { name = v.hl_group, link = false }))
          --- vim.api.nvim_get_hl{link=false} may return {link=...} if the highlight is part of a circular link chain
          and not vim.api.nvim_get_hl(0, { name = v.hl_group, link = false }).link
        then
          table.insert(result, { prev_pos_range[2], pos.range[2], v.hl_group })
          break
        end
      end
    end

    if pos.type == 'start' then
      table.insert(stack, binary_find(stack, pos.priority, pos.subpriority), pos)
    elseif pos.type == 'end' then
      table.remove(stack, binary_find(stack, pos.priority, pos.subpriority) - 1)
    end

    prev_pos_range = pos.range
  end

  return result
end
