local G = vim.lsp._snippet_grammar
local snippet_group = vim.api.nvim_create_augroup('vim/snippet', {})
local snippet_ns = vim.api.nvim_create_namespace('vim/snippet')
local hl_group = 'SnippetTabstop'
local jump_forward_key = '<tab>'
local jump_backward_key = '<s-tab>'

--- Returns the 0-based cursor position.
---
--- @return integer, integer
local function cursor_pos()
  local cursor = vim.api.nvim_win_get_cursor(0)
  return cursor[1] - 1, cursor[2]
end

--- Resolves variables (like `$name` or `${name:default}`) as follows:
--- - When a variable is unknown (i.e.: its name is not recognized in any of the cases below), return `nil`.
--- - When a variable isn't set, return its default (if any) or an empty string.
---
--- Note that in some cases, the default is ignored since it's not clear how to distinguish an empty
--- value from an unset value (e.g.: `TM_CURRENT_LINE`).
---
--- @param var string
--- @param default string
--- @return string?
local function resolve_variable(var, default)
  --- @param str string
  --- @return string
  local function expand_or_default(str)
    local expansion = vim.fn.expand(str) --[[@as string]]
    return expansion == '' and default or expansion
  end

  if var == 'TM_SELECTED_TEXT' then
    -- Snippets are expanded in insert mode only, so there's no selection.
    return default
  elseif var == 'TM_CURRENT_LINE' then
    return vim.api.nvim_get_current_line()
  elseif var == 'TM_CURRENT_WORD' then
    return expand_or_default('<cword>')
  elseif var == 'TM_LINE_INDEX' then
    return tostring(vim.fn.line('.') - 1)
  elseif var == 'TM_LINE_NUMBER' then
    return tostring(vim.fn.line('.'))
  elseif var == 'TM_FILENAME' then
    return expand_or_default('%:t')
  elseif var == 'TM_FILENAME_BASE' then
    return expand_or_default('%:t:r')
  elseif var == 'TM_DIRECTORY' then
    return expand_or_default('%:p:h:t')
  elseif var == 'TM_FILEPATH' then
    return expand_or_default('%:p')
  end

  -- Unknown variable.
  return nil
end

--- Transforms the given text into an array of lines (so no line contains `\n`).
---
--- @param text string|string[]
--- @return string[]
local function text_to_lines(text)
  text = type(text) == 'string' and { text } or text
  --- @cast text string[]
  return vim.split(table.concat(text), '\n', { plain = true })
end

--- Computes the 0-based position of a tabstop located at the end of `snippet` and spanning
--- `placeholder` (if given).
---
--- @param snippet string[]
--- @param placeholder string?
--- @return Range4
local function compute_tabstop_range(snippet, placeholder)
  local cursor_row, cursor_col = cursor_pos()
  local snippet_text = text_to_lines(snippet)
  local placeholder_text = text_to_lines(placeholder or '')
  local start_row = cursor_row + #snippet_text - 1
  local start_col = #(snippet_text[#snippet_text] or '')

  -- Add the cursor's column offset to the first line.
  if start_row == cursor_row then
    start_col = start_col + cursor_col
  end

  local end_row = start_row + #placeholder_text - 1
  local end_col = (start_row == end_row and start_col or 0)
    + #(placeholder_text[#placeholder_text] or '')

  return { start_row, start_col, end_row, end_col }
end

--- Returns the range spanned by the respective extmark.
---
--- @param bufnr integer
--- @param extmark_id integer
--- @return Range4
local function get_extmark_range(bufnr, extmark_id)
  local mark = vim.api.nvim_buf_get_extmark_by_id(bufnr, snippet_ns, extmark_id, { details = true })

  --- @diagnostic disable-next-line: undefined-field
  return { mark[1], mark[2], mark[3].end_row, mark[3].end_col }
end

--- @class (private) vim.snippet.Tabstop
--- @field extmark_id integer
--- @field bufnr integer
--- @field index integer
--- @field choices? string[]
local Tabstop = {}

--- Creates a new tabstop.
---
--- @package
--- @param index integer
--- @param bufnr integer
--- @param range Range4
--- @param choices? string[]
--- @return vim.snippet.Tabstop
function Tabstop.new(index, bufnr, range, choices)
  local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, snippet_ns, range[1], range[2], {
    right_gravity = true,
    end_right_gravity = true,
    end_line = range[3],
    end_col = range[4],
    hl_group = hl_group,
  })

  local self = setmetatable(
    { extmark_id = extmark_id, bufnr = bufnr, index = index, choices = choices },
    { __index = Tabstop }
  )

  return self
end

--- Returns the tabstop's range.
---
--- @package
--- @return Range4
function Tabstop:get_range()
  return get_extmark_range(self.bufnr, self.extmark_id)
end

--- Returns the text spanned by the tabstop.
---
--- @package
--- @return string
function Tabstop:get_text()
  local range = self:get_range()
  return table.concat(
    vim.api.nvim_buf_get_text(self.bufnr, range[1], range[2], range[3], range[4], {}),
    '\n'
  )
end

--- Sets the tabstop's text.
---
--- @package
--- @param text string
function Tabstop:set_text(text)
  local range = self:get_range()
  vim.api.nvim_buf_set_text(self.bufnr, range[1], range[2], range[3], range[4], text_to_lines(text))
end

--- Sets the right gravity of the tabstop's extmark.
---
--- @package
--- @param right_gravity boolean
function Tabstop:set_right_gravity(right_gravity)
  local range = self:get_range()
  self.extmark_id = vim.api.nvim_buf_set_extmark(self.bufnr, snippet_ns, range[1], range[2], {
    right_gravity = right_gravity,
    end_right_gravity = true,
    end_line = range[3],
    end_col = range[4],
    hl_group = hl_group,
  })
end

--- @class (private) vim.snippet.Session
--- @field bufnr integer
--- @field extmark_id integer
--- @field tabstops table<integer, vim.snippet.Tabstop[]>
--- @field current_tabstop vim.snippet.Tabstop
--- @field tab_keymaps { i: table<string, any>?, s: table<string, any>? }
--- @field shift_tab_keymaps { i: table<string, any>?, s: table<string, any>? }
local Session = {}

--- Creates a new snippet session in the current buffer.
---
--- @package
--- @param bufnr integer
--- @param snippet_extmark integer
--- @param tabstop_data table<integer, { range: Range4, choices?: string[] }[]>
--- @return vim.snippet.Session
function Session.new(bufnr, snippet_extmark, tabstop_data)
  local self = setmetatable({
    bufnr = bufnr,
    extmark_id = snippet_extmark,
    tabstops = {},
    current_tabstop = Tabstop.new(0, bufnr, { 0, 0, 0, 0 }),
    tab_keymaps = { i = nil, s = nil },
    shift_tab_keymaps = { i = nil, s = nil },
  }, { __index = Session })

  -- Create the tabstops.
  for index, ranges in pairs(tabstop_data) do
    for _, data in ipairs(ranges) do
      self.tabstops[index] = self.tabstops[index] or {}
      table.insert(self.tabstops[index], Tabstop.new(index, self.bufnr, data.range, data.choices))
    end
  end

  self:set_keymaps()

  return self
end

--- Sets the snippet navigation keymaps.
---
--- @package
function Session:set_keymaps()
  local function maparg(key, mode)
    local map = vim.fn.maparg(key, mode, false, true) --[[ @as table ]]
    if not vim.tbl_isempty(map) and map.buffer == 1 then
      return map
    else
      return nil
    end
  end

  local function set(jump_key, direction)
    vim.keymap.set({ 'i', 's' }, jump_key, function()
      return vim.snippet.active({ direction = direction })
          and '<cmd>lua vim.snippet.jump(' .. direction .. ')<cr>'
        or jump_key
    end, { expr = true, silent = true, buffer = self.bufnr })
  end

  self.tab_keymaps = {
    i = maparg(jump_forward_key, 'i'),
    s = maparg(jump_forward_key, 's'),
  }
  self.shift_tab_keymaps = {
    i = maparg(jump_backward_key, 'i'),
    s = maparg(jump_backward_key, 's'),
  }
  set(jump_forward_key, 1)
  set(jump_backward_key, -1)
end

--- Restores/deletes the keymaps used for snippet navigation.
---
--- @package
function Session:restore_keymaps()
  local function restore(keymap, lhs, mode)
    if keymap then
      vim._with({ buf = self.bufnr }, function()
        vim.fn.mapset(keymap)
      end)
    else
      vim.api.nvim_buf_del_keymap(self.bufnr, mode, lhs)
    end
  end

  restore(self.tab_keymaps.i, jump_forward_key, 'i')
  restore(self.tab_keymaps.s, jump_forward_key, 's')
  restore(self.shift_tab_keymaps.i, jump_backward_key, 'i')
  restore(self.shift_tab_keymaps.s, jump_backward_key, 's')
end

--- Returns the destination tabstop index when jumping in the given direction.
---
--- @package
--- @param direction vim.snippet.Direction
--- @return integer?
function Session:get_dest_index(direction)
  local tabstop_indexes = vim.tbl_keys(self.tabstops) --- @type integer[]
  table.sort(tabstop_indexes)
  for i, index in ipairs(tabstop_indexes) do
    if index == self.current_tabstop.index then
      local dest_index = tabstop_indexes[i + direction] --- @type integer?
      -- When jumping forwards, $0 is the last tabstop.
      if not dest_index and direction == 1 then
        dest_index = 0
      end
      -- When jumping backwards, make sure we don't think that $0 is the first tabstop.
      if dest_index == 0 and direction == -1 then
        dest_index = nil
      end
      return dest_index
    end
  end
end

--- Sets the right gravity of the tabstop group with the given index.
---
--- @package
--- @param index integer
--- @param right_gravity boolean
function Session:set_group_gravity(index, right_gravity)
  for _, tabstop in ipairs(self.tabstops[index]) do
    tabstop:set_right_gravity(right_gravity)
  end
end

local M = { session = nil }

--- Displays the choices for the given tabstop as completion items.
---
--- @param tabstop vim.snippet.Tabstop
local function display_choices(tabstop)
  assert(tabstop.choices, 'Tabstop has no choices')

  local start_col = tabstop:get_range()[2] + 1
  local matches = {} --- @type table[]
  for _, choice in ipairs(tabstop.choices) do
    matches[#matches + 1] = { word = choice }
  end

  vim.defer_fn(function()
    vim.fn.complete(start_col, matches)
  end, 100)
end

--- Select the given tabstop range.
---
--- @param tabstop vim.snippet.Tabstop
local function select_tabstop(tabstop)
  --- @param keys string
  local function feedkeys(keys)
    keys = vim.api.nvim_replace_termcodes(keys, true, false, true)
    vim.api.nvim_feedkeys(keys, 'n', true)
  end

  --- NOTE: We don't use `vim.api.nvim_win_set_cursor` here because it causes the cursor to end
  --- at the end of the selection instead of the start.
  ---
  --- @param row integer
  --- @param col integer
  local function move_cursor_to(row, col)
    local line = vim.fn.getline(row) --[[ @as string ]]
    col = math.max(vim.fn.strchars(line:sub(1, col)) - 1, 0)
    feedkeys(string.format('%sG0%s', row, string.rep('<Right>', col)))
  end

  local range = tabstop:get_range()
  local mode = vim.fn.mode()

  if vim.fn.pumvisible() ~= 0 then
    -- Close the choice completion menu if open.
    vim.fn.complete(vim.fn.col('.'), {})
  end

  -- Move the cursor to the start of the tabstop.
  vim.api.nvim_win_set_cursor(0, { range[1] + 1, range[2] })

  -- For empty, choice and the final tabstops, start insert mode at the end of the range.
  if tabstop.choices or tabstop.index == 0 or (range[1] == range[3] and range[2] == range[4]) then
    if mode ~= 'i' then
      if mode == 's' then
        feedkeys('<Esc>')
      end
      vim.cmd.startinsert({ bang = range[4] >= #vim.api.nvim_get_current_line() })
    end
    if tabstop.choices then
      display_choices(tabstop)
    end
  else
    -- Else, select the tabstop's text.
    if mode ~= 'n' then
      feedkeys('<Esc>')
    end
    move_cursor_to(range[1] + 1, range[2] + 1)
    feedkeys('v')
    move_cursor_to(range[3] + 1, range[4])
    feedkeys('o<c-g><c-r>_')
  end
end

--- Sets up the necessary autocommands for snippet expansion.
---
--- @param bufnr integer
local function setup_autocmds(bufnr)
  vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
    group = snippet_group,
    desc = 'Update snippet state when the cursor moves',
    buffer = bufnr,
    callback = function()
      -- Just update the tabstop in insert and select modes.
      if not vim.fn.mode():match('^[isS]') then
        return
      end

      local cursor_row, cursor_col = cursor_pos()

      -- The cursor left the snippet region.
      local snippet_range = get_extmark_range(bufnr, M._session.extmark_id)
      if
        cursor_row < snippet_range[1]
        or (cursor_row == snippet_range[1] and cursor_col < snippet_range[2])
        or cursor_row > snippet_range[3]
        or (cursor_row == snippet_range[3] and cursor_col > snippet_range[4])
      then
        M.stop()
        return true
      end

      for tabstop_index, tabstops in pairs(M._session.tabstops) do
        for _, tabstop in ipairs(tabstops) do
          local range = tabstop:get_range()
          if
            (cursor_row > range[1] or (cursor_row == range[1] and cursor_col >= range[2]))
            and (cursor_row < range[3] or (cursor_row == range[3] and cursor_col <= range[4]))
          then
            if tabstop_index ~= 0 then
              return
            end
          end
        end
      end

      -- The cursor is either not on a tabstop or we reached the end, so exit the session.
      M.stop()
      return true
    end,
  })

  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    group = snippet_group,
    desc = 'Update active tabstops when buffer text changes',
    buffer = bufnr,
    callback = function()
      -- Check that the snippet hasn't been deleted.
      local snippet_range = get_extmark_range(M._session.bufnr, M._session.extmark_id)
      if
        (snippet_range[1] == snippet_range[3] and snippet_range[2] == snippet_range[4])
        or snippet_range[3] + 1 > vim.fn.line('$')
      then
        M.stop()
      end

      if not M.active() then
        return true
      end

      -- Sync the tabstops in the current group.
      local current_tabstop = M._session.current_tabstop
      local current_text = current_tabstop:get_text()
      for _, tabstop in ipairs(M._session.tabstops[current_tabstop.index]) do
        if tabstop.extmark_id ~= current_tabstop.extmark_id then
          tabstop:set_text(current_text)
        end
      end
    end,
  })

  vim.api.nvim_create_autocmd('BufLeave', {
    group = snippet_group,
    desc = 'Stop the snippet session when leaving the buffer',
    buffer = bufnr,
    callback = function()
      M.stop()
    end,
  })
end

--- Expands the given snippet text.
--- Refer to https://microsoft.github.io/language-server-protocol/specification/#snippet_syntax
--- for the specification of valid input.
---
--- Tabstops are highlighted with |hl-SnippetTabstop|.
---
--- @param input string
function M.expand(input)
  local snippet = G.parse(input)
  local snippet_text = {}
  local base_indent = vim.api.nvim_get_current_line():match('^%s*') or ''

  -- Get the placeholders we should use for each tabstop index.
  --- @type table<integer, string>
  local placeholders = {}
  for _, child in ipairs(snippet.data.children) do
    local type, data = child.type, child.data
    if type == G.NodeType.Placeholder then
      --- @cast data vim.snippet.PlaceholderData
      local tabstop, value = data.tabstop, tostring(data.value)
      if placeholders[tabstop] and placeholders[tabstop] ~= value then
        error('Snippet has multiple placeholders for tabstop $' .. tabstop)
      end
      placeholders[tabstop] = value
    end
  end

  -- Keep track of tabstop nodes during expansion.
  --- @type table<integer, { range: Range4, choices?: string[] }[]>
  local tabstop_data = {}

  --- @param index integer
  --- @param placeholder? string
  --- @param choices? string[]
  local function add_tabstop(index, placeholder, choices)
    tabstop_data[index] = tabstop_data[index] or {}
    local range = compute_tabstop_range(snippet_text, placeholder)
    table.insert(tabstop_data[index], { range = range, choices = choices })
  end

  --- Appends the given text to the snippet, taking care of indentation.
  ---
  --- @param text string|string[]
  local function append_to_snippet(text)
    local snippet_lines = text_to_lines(snippet_text)
    -- Get the base indentation based on the current line and the last line of the snippet.
    if #snippet_lines > 0 then
      base_indent = base_indent .. (snippet_lines[#snippet_lines]:match('(^%s+)%S') or '') --- @type string
    end

    local shiftwidth = vim.fn.shiftwidth()
    local curbuf = vim.api.nvim_get_current_buf()
    local expandtab = vim.bo[curbuf].expandtab

    local lines = {} --- @type string[]
    for i, line in ipairs(text_to_lines(text)) do
      -- Replace tabs by spaces.
      if expandtab then
        line = line:gsub('\t', (' '):rep(shiftwidth)) --- @type string
      end
      -- Add the base indentation.
      if i > 1 then
        line = base_indent .. line
      end
      lines[#lines + 1] = line
    end

    table.insert(snippet_text, table.concat(lines, '\n'))
  end

  for _, child in ipairs(snippet.data.children) do
    local type, data = child.type, child.data
    if type == G.NodeType.Tabstop then
      --- @cast data vim.snippet.TabstopData
      local placeholder = placeholders[data.tabstop]
      add_tabstop(data.tabstop, placeholder)
      if placeholder then
        append_to_snippet(placeholder)
      end
    elseif type == G.NodeType.Placeholder then
      --- @cast data vim.snippet.PlaceholderData
      local value = placeholders[data.tabstop]
      add_tabstop(data.tabstop, value)
      append_to_snippet(value)
    elseif type == G.NodeType.Choice then
      --- @cast data vim.snippet.ChoiceData
      add_tabstop(data.tabstop, nil, data.values)
    elseif type == G.NodeType.Variable then
      --- @cast data vim.snippet.VariableData
      -- Try to get the variable's value.
      local value = resolve_variable(data.name, data.default and tostring(data.default) or '')
      if not value then
        -- Unknown variable, make this a tabstop and use the variable name as a placeholder.
        value = data.name
        local tabstop_indexes = vim.tbl_keys(tabstop_data)
        local index = math.max(unpack((#tabstop_indexes == 0 and { 0 }) or tabstop_indexes)) + 1
        add_tabstop(index, value)
      end
      append_to_snippet(value)
    elseif type == G.NodeType.Text then
      --- @cast data vim.snippet.TextData
      append_to_snippet(data.text)
    end
  end

  -- $0, which defaults to the end of the snippet, defines the final cursor position.
  -- Make sure the snippet has exactly one of these.
  if vim.tbl_contains(vim.tbl_keys(tabstop_data), 0) then
    assert(#tabstop_data[0] == 1, 'Snippet has multiple $0 tabstops')
  else
    add_tabstop(0)
  end

  snippet_text = text_to_lines(snippet_text)

  -- Insert the snippet text.
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_row, cursor_col = cursor_pos()
  vim.api.nvim_buf_set_text(bufnr, cursor_row, cursor_col, cursor_row, cursor_col, snippet_text)

  -- Create the session.
  local snippet_extmark = vim.api.nvim_buf_set_extmark(bufnr, snippet_ns, cursor_row, cursor_col, {
    end_line = cursor_row + #snippet_text - 1,
    end_col = #snippet_text > 1 and #snippet_text[#snippet_text] or cursor_col + #snippet_text[1],
    right_gravity = false,
    end_right_gravity = true,
  })
  M._session = Session.new(bufnr, snippet_extmark, tabstop_data)

  -- Jump to the first tabstop.
  M.jump(1)
end

--- @alias vim.snippet.Direction -1 | 1

--- Jumps to the next (or previous) placeholder in the current snippet, if possible.
---
--- For example, map `<Tab>` to jump while a snippet is active:
---
--- ```lua
--- vim.keymap.set({ 'i', 's' }, '<Tab>', function()
---    if vim.snippet.active({ direction = 1 }) then
---      return '<Cmd>lua vim.snippet.jump(1)<CR>'
---    else
---      return '<Tab>'
---    end
---  end, { expr = true })
--- ```
---
--- @param direction (vim.snippet.Direction) Navigation direction. -1 for previous, 1 for next.
function M.jump(direction)
  -- Get the tabstop index to jump to.
  local dest_index = M._session and M._session:get_dest_index(direction)
  if not dest_index then
    return
  end

  -- Find the tabstop with the lowest range.
  local tabstops = M._session.tabstops[dest_index]
  local dest = tabstops[1]
  for _, tabstop in ipairs(tabstops) do
    local dest_range, range = dest:get_range(), tabstop:get_range()
    if (range[1] < dest_range[1]) or (range[1] == dest_range[1] and range[2] < dest_range[2]) then
      dest = tabstop
    end
  end

  -- Clear the autocommands so that we can move the cursor freely while selecting the tabstop.
  vim.api.nvim_clear_autocmds({ group = snippet_group, buffer = M._session.bufnr })

  -- Deactivate expansion of the current tabstop.
  M._session:set_group_gravity(M._session.current_tabstop.index, true)

  M._session.current_tabstop = dest
  select_tabstop(dest)

  -- Activate expansion of the destination tabstop.
  M._session:set_group_gravity(dest.index, false)

  -- Restore the autocommands.
  setup_autocmds(M._session.bufnr)
end

--- @class vim.snippet.ActiveFilter
--- @field direction vim.snippet.Direction Navigation direction. -1 for previous, 1 for next.

--- Returns `true` if there's an active snippet in the current buffer,
--- applying the given filter if provided.
---
--- You can use this function to navigate a snippet as follows:
---
--- ```lua
--- vim.keymap.set({ 'i', 's' }, '<Tab>', function()
---    if vim.snippet.active({ direction = 1 }) then
---      return '<Cmd>lua vim.snippet.jump(1)<CR>'
---    else
---      return '<Tab>'
---    end
---  end, { expr = true })
--- ```
---
--- @param filter? vim.snippet.ActiveFilter Filter to constrain the search with:
--- - `direction` (vim.snippet.Direction): Navigation direction. Will return `true` if the snippet
--- can be jumped in the given direction.
--- @return boolean
function M.active(filter)
  local active = M._session ~= nil and M._session.bufnr == vim.api.nvim_get_current_buf()

  local in_direction = true
  if active and filter and filter.direction then
    in_direction = M._session:get_dest_index(filter.direction) ~= nil
  end

  return active and in_direction
end

--- Exits the current snippet.
function M.stop()
  if not M.active() then
    return
  end

  M._session:restore_keymaps()

  vim.api.nvim_clear_autocmds({ group = snippet_group, buffer = M._session.bufnr })
  vim.api.nvim_buf_clear_namespace(M._session.bufnr, snippet_ns, 0, -1)

  M._session = nil
end

return M
