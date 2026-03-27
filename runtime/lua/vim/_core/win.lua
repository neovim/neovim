---@alias vim._set_layout.Node
---     | [ 'leaf', integer, { focused?: boolean } ]
---     | [ 'row'|'col', vim._set_layout.Node[] ]

---@param tabpage integer
---@param layout vim._set_layout.Node
function vim._set_layout(tabpage, layout)
  if layout[1] == 'leaf' then
    -- top-level node is a leaf
    -- simplify the main traversal loop by special-casing this

    local buf = layout[2] --[[@as integer]]
    if type(buf) == 'string' then
      buf = vim.fn.bufadd(buf)
      vim.api.nvim_set_option_value('buflisted', true, {
        buf = buf,
      })
    end
    vim.api.nvim_win_set_buf(vim.api.nvim_tabpage_get_win(tabpage), buf)
    return
  end

  -- Breadth-first traversal of the expected layout tree, creating windows as we go.
  -- We always create splits top to bottom, left to right.
  --
  -- Focus target is saved during traversal and focused at the end to avoid focus-dependent split
  -- behavior.
  local queue = { layout }
  local focus = nil

  while #queue > 0 do
    local node = table.remove(queue, 1)
    local last = vim.api.nvim_tabpage_get_win(tabpage)
    local split = node[1] == 'row' and 'right' or 'below'

    for i = 1, #node[2] do
      ---@type vim._set_layout.Node
      local child_node = node[2][i]

      -- For the first child, we reuse the existing window.
      if i > 1 then
        last = vim.api.nvim_open_win(0, false, {
          split = split,
          win = last,
        })
      end

      if child_node[1] == 'leaf' then
        local buf = child_node[2] --[[@as integer|string]]
        if type(buf) == 'string' then
          buf = vim.fn.bufadd(buf)
          vim.api.nvim_set_option_value('buflisted', true, {
            buf = buf,
          })
        end
        vim.api.nvim_win_set_buf(last, buf)

        -- Mark window for focusing after the layout setup is complete
        if child_node[3] and child_node[3].focused then
          focus = last
        end
      else
        table.insert(queue, child_node)
      end
    end
  end
  if focus and vim.api.nvim_win_is_valid(focus) then
    vim.api.nvim_tabpage_set_win(tabpage, focus)
  end
end
