local lsp_snippet = require('vim.lsp._snippet')

---@alias vim.snippet.MarkId integer
---@alias vim.snippet.Tabstop integer
---@alias vim.snippet.Changenr integer
---@alias vim.snippet.Position { [1]: integer, [2]: integer } # The 0-origin utf8 byte index.
---@alias vim.snippet.Range { s: vim.snippet.Position, e: vim.snippet.Position } # The 0-origin utf8 byte index.

---@class vim.snippet.TraverseContext
---@field depth integer
---@field range vim.snippet.Range
---@field replace fun(new_node: vim.lsp.snippet.Node): nil

---Feed keys.
---NOTE: This always enables `virtualedit=onemore`
---@param keys string
local function feedkeys(keys)
  local k = {}
  table.insert(k, '<Cmd>set virtualedit=onemore<CR>')
  table.insert(k, keys)
  table.insert(k, ('<Cmd>set virtualedit=%s<CR>'):format(vim.o.virtualedit))
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(table.concat(k), true, true, true), 'ni', true)
end

---Return true if range contains position.
---@param range vim.snippet.Range
---@param position vim.snippet.Position
---@return boolean
local function within(range, position)
  -- Check the cursor is before the range start position.
  if position[1] < range.s[1] or (position[1] == range.s[1] and position[2] < range.s[2]) then
    return false
  end

  -- Check the cursor is after the range end position.
  if range.e[1] < position[1] or (range.e[1] == position[1] and range.e[2] < position[2]) then
    return false
  end

  return true
end

---Return cursor position.
---@return vim.snippet.Position
local function cursor_position()
  local cursor = vim.api.nvim_win_get_cursor(0)
  return { cursor[1] - 1, cursor[2] }
end

---Return one indent string of current buffer.
---@return string
local function get_one_indent()
  local expandtab = vim.api.nvim_get_option('expandtab')
  if not expandtab then
    return '\t'
  end
  local shiftwidth = vim.api.nvim_get_option('shiftwidth')
  if shiftwidth > 0 then
    return string.rep(' ', shiftwidth)
  end
  return string.rep(' ', vim.api.nvim_get_option('tabstop'))
end

---Return base indent of current line.
---@return string
local function get_base_indent()
  return string.match(vim.api.nvim_get_current_line(), '^%s*') or ''
end

---Adjust snippet indent
---@param snippet_text string
---@return string
local function adjust_indent(snippet_text)
  local one_indent = get_one_indent()
  local base_indent = get_base_indent()

  local adjusted_snippet_text = {}
  local snippet_lines = vim.split(snippet_text, '\n', { plain = true })
  for i, line in ipairs(snippet_lines) do
    if i == 1 then
      -- Use first line as-is.
      table.insert(adjusted_snippet_text, line)
    elseif i ~= #snippet_lines and string.match(line, '^%s*$') then
      -- Remove space only lines except the last line.
      table.insert(adjusted_snippet_text, '')
    else
      -- 1. Change \t as one_indent.
      -- 2. Add base_indent.
      line = string.gsub(line, '^(\t+)', function(indent)
        return string.gsub(indent, '\t', one_indent)
      end)
      table.insert(adjusted_snippet_text, base_indent .. line)
    end
  end
  return table.concat(adjusted_snippet_text, '\n')
end

---Get range from extmark.
---@param ns integer
---@param mark_id vim.snippet.MarkId
---@return vim.snippet.Range
local function get_range_from_mark(ns, mark_id)
  local mark = vim.api.nvim_buf_get_extmark_by_id(0, ns, mark_id, { details = true })
  local s = { mark[1], mark[2] }
  local e = { mark[3].end_row, mark[3].end_col }
  if s[1] > e[1] or (s[1] == e[1] and s[2] > e[2]) then
    local t = s
    s = e
    e = t
  end
  return { s = s, e = e }
end

---Get text from range.
---@param range vim.snippet.Range
---@return string
local function get_text_by_range(range)
  local lines = vim.api.nvim_buf_get_lines(0, range.s[1], range.e[1] + 1, false)
  if range.s[1] ~= range.e[1] then
    lines[1] = string.sub(lines[1], range.s[2] + 1)
    lines[#lines] = string.sub(lines[#lines], 1, range.e[2])
  else
    lines[1] = string.sub(lines[1], range.s[2] + 1, range.e[2])
  end
  return table.concat(lines, '\n')
end

---Traverse snippet ast.
---The `context.range` is calculated by `tostring(node)`, so it can be used only for processing before snippet insertion.
---@param snippet_node table
---@param callback fun(node: table, context: vim.snippet.TraverseContext): table|nil
local function traverse(snippet_node, callback)
  ---Traverse snippet ast.
  ---@param node table
  ---@param context vim.snippet.TraverseContext
  ---@param position vim.snippet.Position
  local function traverse_recursive(node, context, position)
    -- Memoize starting position of this node.
    local start_position = { position[1], position[2] }

    if node.children then
      -- Traverse children.
      for i, child in ipairs(node.children) do
        traverse_recursive(child, {
          depth = context.depth + 1,
          replace = (function(children, index)
            return function(new_node)
              children[index] = new_node
            end
          end)(node.children, i)
        }, position)
      end
    else
      -- Update position if this node is Text node.
      local texts = vim.split(tostring(node), '\n')
      position[1] = position[1] + #texts - 1
      position[2] = #texts > 1 and #texts[#texts] or (position[2] + #texts[1])
    end

    -- Callback with range of this node.
    context.range = { s = start_position, e = { position[1], position[2] } }
    callback(node, context)
  end

  -- Start traversing.
  traverse_recursive(snippet_node, {
    depth = 0,
    replace = function()
      -- noop: the root node can't be replaced.
    end
  }, { 0, 0 })
end

---Jump to specific mark.
---@param mark vim.snippet.SnippetMark
local function jump_to_mark(mark)
  local range = mark:get_range()
  if mark.node.type == lsp_snippet.Node.Type.Choice then
    feedkeys(([[<Cmd>call cursor(%s,%s)<CR><Cmd>complete(%s, %s)<CR>]]):format(
      range.e[1] + 1,
      range.e[2] + 1,
      range.s[2] + 1,
      vim.json.encode(mark.node.items)
    ))
  else
    if range.s[1] == range.e[1] and range.s[2] == range.e[2] then
      -- jump.
      feedkeys(([[<Esc><Cmd>call cursor(%s,%s)<CR>i]]):format(range.e[1] + 1, range.e[2] + 1))
    else
      -- select text and save `'<` / `'>` register.
      feedkeys(([[<Esc><Cmd>call cursor(%s,%s)<CR>v<Cmd>call cursor(%s,%s)<CR><Esc>gvo<C-g>]]):format(
        range.s[1] + 1,
        range.s[2] + 1,
        range.e[1] + 1,
        range.e[2] + (vim.o.selection == 'exclusive' and 1 or 0)
      ))
    end
  end
end

---Resolve variables.
---NOTE: This function doesn't support fast-event.
---@param var_name string
---@return (integer|string)?
local function resolve_variable(var_name)
  if var_name == 'TM_SELECTED_TEXT' then
    return ''
  elseif var_name == 'TM_CURRENT_LINE' then
    return vim.api.nvim_get_current_line()
  elseif var_name == 'TM_CURRENT_WORD' then
    local line = vim.api.nvim_get_current_line()
    local before = string.sub(line, 1, cursor_position()[2])
    local word_s = vim.regex([[\k\+$]]):match_str(before) or #before
    local word_after = string.sub(line, word_s + 1)
    local _, word_e = vim.regex([[^\k\+]]):match_str(word_after)
    return string.sub(line, word_s + 1, (word_e or word_s - 1) + 1)
  elseif var_name == 'TM_LINE_INDEX' then
    return cursor_position()[1]
  elseif var_name == 'TM_LINE_NUMBER' then
    return cursor_position()[1] + 1
  elseif var_name == 'TM_FILENAME' then
    return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':p:t')
  elseif var_name == 'TM_FILENAME_BASE' then
    return (string.gsub(vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':p:t'), '%.[^%.]*$', ''))
  elseif var_name == 'TM_DIRECTORY' then
    return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':p:h:t')
  elseif var_name == 'TM_FILEPATH' then
    return vim.api.nvim_buf_get_name(0)
  end
  return nil -- unknown variable.
end

---Analyze snippet text.
--- The returned tree will have tab stops numbered sequentially starting with 1.
---@param snippet_text string
---@return { node: table, text: string, tabstop_count: integer }
local function create_normalized_tree(snippet_text)
  local normalized = {
    node = lsp_snippet.parse(snippet_text),
    text = '',
    tabstop_count = 0,
  }

  -- Normalize tree.
  local tabstop_nodes_map = {}
  local has_trailing_tabstop = false
  traverse(normalized.node, function(node, context)
    if type(node.tabstop) == 'number' then
      -- Store 0-tabstop is exists or not.
      has_trailing_tabstop = has_trailing_tabstop or node.tabstop == 0

      -- Replace 0-tabstop as huge number.
      node.tabstop = node.tabstop == 0 and math.huge or node.tabstop

      -- Ensure nodes per each tabstops.
      tabstop_nodes_map[node.tabstop] = tabstop_nodes_map[node.tabstop] or {}
      local origin_node = tabstop_nodes_map[node.tabstop][1]
      if origin_node then
        -- Replace as cloned origin node if same tabstop already exists.
        -- The origin node is first node in each tabstop.
        context.replace(setmetatable(vim.tbl_deep_extend('keep', {}, origin_node), lsp_snippet.Node))
      end
      table.insert(tabstop_nodes_map[node.tabstop], node)
    elseif lsp_snippet.Node.Type.Variable == node.type then
      local resolved_text = resolve_variable(node.name)
      context.replace(setmetatable({
        type = lsp_snippet.Node.Type.Text,
        raw = resolved_text,
        esc = resolved_text,
      }, lsp_snippet.Node))
    end
  end)

  -- Re-order tabstops sequentially starting from 1.
  local tabstops = vim.tbl_keys(tabstop_nodes_map)
  table.sort(tabstops, function(a, b) return a < b end)
  for i, tabstop in ipairs(tabstops) do
    for _, node in ipairs(tabstop_nodes_map[tabstop]) do
      node.tabstop = i
    end
  end
  normalized.tabstop_count = #tabstops

  -- Append final-tabstop if not exists.
  if not has_trailing_tabstop then
    table.insert(normalized.node.children, setmetatable({
      type = lsp_snippet.Node.Type.Tabstop,
      tabstop = #tabstops + 1,
    }, lsp_snippet.Node))
    normalized.tabstop_count = normalized.tabstop_count + 1
  end

  -- Create first insertion text.
  traverse(normalized.node, function(node)
    if vim.tbl_contains({ lsp_snippet.Node.Type.Text, lsp_snippet.Node.Type.Choice, }, node.type) then
      normalized.text = normalized.text .. tostring(node)
    end
  end)

  return normalized
end

---@class vim.snippet.SnippetController
---@field public session? vim.snippet.SnippetSession
local SnippetController = {
  session = nil,
}

---@enum vim.snippet.JumpDirection
local JumpDirection = {
  Next = 1,
  Prev = 2,
}

---@class vim.snippet.SnippetMark
---@field public bufnr integer
---@field public ns integer
---@field public mark_id vim.snippet.MarkId
---@field public node vim.lsp.snippet.Node
---@field public text string
---@field public is_origin boolean
---@field public origin_node? vim.lsp.snippet.Node
local SnippetMark = {}

---Create SnippetMark instance.
---@param params { ns: integer, mark_id: vim.snippet.MarkId, node: vim.lsp.snippet.Node, range: vim.snippet.Range, origin_node?: vim.lsp.snippet.Node }
function SnippetMark.new(params)
  local self = setmetatable({}, { __index = SnippetMark })
  self.ns = params.ns
  self.mark_id = params.mark_id
  self.node = params.node
  self.is_origin = not params.origin_node
  self.origin_node = params.origin_node
  self.text = get_text_by_range(get_range_from_mark(params.ns, params.mark_id))
  return self
end

---Get actual range from extmark.
---@return vim.snippet.Range
function SnippetMark:get_range()
  return get_range_from_mark(self.ns, self.mark_id)
end

---Set range.
---@param range vim.snippet.Range
function SnippetMark:set_range(range)
  vim.api.nvim_buf_set_extmark(0, self.ns, range.s[1], range.s[2], {
    id = self.mark_id,
    end_line = range.e[1],
    end_col = range.e[2],
    right_gravity = false,
    end_right_gravity = true,
  })
end

---Get current node text.
---@return string
function SnippetMark:get_node_text()
  return self.text
end

---Set current node text.
---@param new_text string
function SnippetMark:set_node_text(new_text)
  self.text = new_text
end

---Synchronize text content.
function SnippetMark:sync()
  local range = self:get_range()
  if get_text_by_range(range) ~= self.text then
    vim.cmd([[silent! undojoin]])
    vim.api.nvim_buf_set_text(0, range.s[1], range.s[2], range.e[1], range.e[2], vim.split(self.text, '\n'))
  end
end

---Dispose.
function SnippetMark:dispose()
  vim.api.nvim_buf_del_extmark(0, self.ns, self.mark_id)
end

---@class vim.snippet.SnippetSession
---@field public ns integer
---@field public bufnr integer
---@field public marks vim.snippet.SnippetMark[]
---@field public history table<vim.snippet.Changenr, table<vim.snippet.MarkId, vim.snippet.Range>>
---@field public disposed boolean
---@field public changedtick integer
---@field public current_tabstop integer
---@field public snippet_mark_ns integer
---@field public snippet_mark_id vim.snippet.MarkId
local SnippetSession = {}

---Create SnippetSession instance.
---@param bufnr integer
---@param namespace string
function SnippetSession.new(bufnr, namespace)
  local self = setmetatable({}, { __index = SnippetSession })
  self.ns = vim.api.nvim_create_namespace(namespace)
  self.bufnr = bufnr
  self.marks = {}
  self.history = {}
  self.disposed = false
  self.changedtick = 0
  self.current_tabstop = 0
  self.snippet_mark_ns = vim.api.nvim_create_namespace(namespace .. ':snippet')
  self.snippet_mark_id = 0
  return self
end

---Merge snippet to the current snippet session.
---@param new_snippet_text string
function SnippetSession:merge(new_snippet_text)
  local cursor = cursor_position()

  -- Determine cursor tabstop. (prefer the current tabstop if multiple tabstops are found).
  local cursor_tabstop
  for i = #self.marks, 1, -1 do
    local mark = self.marks[i]
    if within(mark:get_range(), cursor) then
      if not cursor_tabstop or mark.node.tabstop == self.current_tabstop then
        cursor_tabstop = mark.node.tabstop
      end
    end
  end
  cursor_tabstop = cursor_tabstop or 1

  -- Insert snippet text.
  local normalized = create_normalized_tree(adjust_indent(new_snippet_text))
  vim.api.nvim_buf_set_text(0, cursor[1], cursor[2], cursor[1], cursor[2], vim.split(normalized.text, '\n'))
  vim.api.nvim_win_set_cursor(0, { cursor[1] + 1, cursor[2] })

  -- Shift tabstops after cursor tabstop by new snippet tabstop count.
  for _, mark in ipairs(self.marks) do
    if mark.node.tabstop > cursor_tabstop then
      mark.node.tabstop = mark.node.tabstop + normalized.tabstop_count
    end
  end

  -- Create tabstop marks & Correct tabstops by cursor tabstop.
  local origin_nodes = {} ---@type table<vim.snippet.Tabstop, vim.lsp.snippet.Node>
  traverse(normalized.node, function(node, context)
    if type(node.tabstop) == 'number' then
      -- Correct tabstop by cursor tabstop.
      node.tabstop = node.tabstop + cursor_tabstop

      local buffer_range = {
        s = { context.range.s[1] + cursor[1], context.range.s[2] + (context.range.s[1] == 0 and cursor[2] or 0) },
        e = { context.range.e[1] + cursor[1], context.range.e[2] + (context.range.e[1] == 0 and cursor[2] or 0) },
      } ---@type vim.snippet.Range

      table.insert(self.marks, SnippetMark.new({
        ns = self.ns,
        node = node,
        origin_node = origin_nodes[node.tabstop],
        mark_id = vim.api.nvim_buf_set_extmark(self.bufnr, self.ns, buffer_range.s[1], buffer_range.s[2], {
          end_line = buffer_range.e[1],
          end_col = buffer_range.e[2],
          right_gravity = false,
          end_right_gravity = true,
        })
      }))
      origin_nodes[node.tabstop] = origin_nodes[node.tabstop] or node
    end
  end)

  -- Initialize.
  self:sync()
  self:jump(vim.snippet.JumpDirection.Next)
end

---Expand snippet to the current buffer.
---@param snippet_text string
function SnippetSession:expand(snippet_text)
  local cursor = cursor_position()

  -- Insert snippet text.
  local normalized = create_normalized_tree(adjust_indent(snippet_text))
  local texts = vim.split(normalized.text, '\n')
  vim.api.nvim_buf_set_text(0, cursor[1], cursor[2], cursor[1], cursor[2], texts)
  vim.api.nvim_win_set_cursor(0, { cursor[1] + 1, cursor[2] })

  -- Create tabstop marks.
  local origin_nodes = {} ---@type table<vim.snippet.Tabstop, vim.lsp.snippet.Node>
  traverse(normalized.node, function(node, context)
    if type(node.tabstop) == 'number' then
      local buffer_range = {
        s = { context.range.s[1] + cursor[1], context.range.s[2] + (context.range.s[1] == 0 and cursor[2] or 0) },
        e = { context.range.e[1] + cursor[1], context.range.e[2] + (context.range.e[1] == 0 and cursor[2] or 0) },
      } ---@type vim.snippet.Range

      table.insert(self.marks, SnippetMark.new({
        ns = self.ns,
        node = node,
        origin_node = origin_nodes[node.tabstop],
        mark_id = vim.api.nvim_buf_set_extmark(self.bufnr, self.ns, buffer_range.s[1], buffer_range.s[2], {
          end_line = buffer_range.e[1],
          end_col = buffer_range.e[2],
          right_gravity = false,
          end_right_gravity = true,
        })
      }))
      origin_nodes[node.tabstop] = origin_nodes[node.tabstop] or node
    end
  end)

  -- Create whole region mark.
  self.snippet_mark_id = vim.api.nvim_buf_set_extmark(self.bufnr, self.snippet_mark_ns, cursor[1], cursor[2], {
    end_line = cursor[1] + (#texts - 1),
    end_col = #texts > 1 and #texts[#texts] or cursor[2] + #texts[1],
    right_gravity = false,
    end_right_gravity = true,
  })

  -- Initialize.
  self:sync()
  self.current_tabstop = 0
  self:jump(vim.snippet.JumpDirection.Next)
end

---Jump to the suitable placeholder.
---@param direction vim.snippet.JumpDirection
function SnippetSession:jump(direction)
  local next_mark = self:find_next_mark(direction)
  if next_mark then
    self.current_tabstop = next_mark.node.tabstop
    jump_to_mark(next_mark)
    self:sync()
  end
end

---Find next mark.
---@param direction vim.snippet.JumpDirection
---@return table
function SnippetSession:find_next_mark(direction)
  local target_mark = nil
  for _, mark in ipairs(self.marks) do
    if direction == JumpDirection.Next then
      if self.current_tabstop < mark.node.tabstop then
        if not target_mark or mark.node.tabstop < target_mark.node.tabstop then
          target_mark = mark
        end
      end
    elseif direction == JumpDirection.Prev and self.current_tabstop > mark.node.tabstop then
      if self.current_tabstop > mark.node.tabstop then
        if not target_mark or mark.node.tabstop > target_mark.node.tabstop then
          target_mark = mark
        end
      end
    end
  end
  return target_mark
end

---Synchronize tabstop texts.
function SnippetSession:sync()
  --- Ignore if the buffer isn't changed.
  local changedtick = vim.api.nvim_buf_get_changedtick(0)
  if self.changedtick == changedtick then
    return
  end
  self.changedtick = changedtick

  -- Check snippet range is not empty.
  local snippet_range = get_range_from_mark(self.snippet_mark_ns, self.snippet_mark_id)
  if snippet_range.s[1] == snippet_range.e[1] and snippet_range.s[2] == snippet_range.e[2] then
    return self:dispose()
  end

  -- Check the changes are included in snippet range.
  if not self:within() then
    return self:dispose()
  end

  local changenr = vim.fn.changenr()

  -- Restore memoized state if changes are occurred by undo/redo.
  local undotree = vim.fn.undotree()
  if undotree.seq_last ~= undotree.seq_cur then
    for _, mark in ipairs(self.marks) do
      mark:set_node_text(get_text_by_range(mark:get_range()))
      if self.history[changenr] and self.history[changenr][mark.mark_id] then
        mark:set_range(self.history[changenr][mark.mark_id])
      end
    end
    return
  end

  -- Save current state to history.
  self.history[changenr] = {}
  for _, mark in ipairs(self.marks) do
    self.history[changenr][mark.mark_id] = mark:get_range()
  end

  -- Dispose directly modified non-origin marks.
  for i = #self.marks, 1, -1 do
    local mark = self.marks[i]
    if mark.origin_node then
      if mark:get_node_text() ~= get_text_by_range(mark:get_range()) then
        table.remove(self.marks, i)
        mark:dispose()
      end
    end
  end

  local origin_marks = {} ---@type table<vim.snippet.Tabstop, vim.snippet.SnippetMark>

  -- Sync origin marks with pysical buffer text.
  for _, mark in ipairs(self.marks) do
    if not mark.origin_node then
      origin_marks[mark.node.tabstop] = mark
      mark:set_node_text(get_text_by_range(mark:get_range()))
      mark:sync()
    end
  end

  -- Sync non-origin marks with origin marks.
  for _, mark in ipairs(self.marks) do
    if mark.origin_node then
      mark:set_node_text(origin_marks[mark.node.tabstop]:get_node_text())
      mark:sync()
    end
  end
end

---Return the cursor is within the snippet range or not.
---@return boolean
function SnippetSession:within()
  if self.disposed then
    return false
  end

  -- Check the buffer is attched.
  if self.bufnr ~= vim.api.nvim_get_current_buf() then
    return false
  end

  return within(get_range_from_mark(self.snippet_mark_ns, self.snippet_mark_id), cursor_position())
end

---Dispose snippet session.
function SnippetSession:dispose()
  for _, mark in ipairs(self.marks) do
    mark:dispose()
  end
  vim.api.nvim_buf_del_extmark(self.bufnr, self.snippet_mark_ns, self.snippet_mark_id)
  self.disposed = true
end

---The vim.snippet's public APIs.
local M = {}

M.JumpDirection = JumpDirection

---Return the cursor is in the activated snippet or not.
---@return boolean
function M._in_context()
  local session = SnippetController.session
  if not session or session.disposed then
    return false
  end
  return session:within()
end

---Sync current modification.
---NOTE: for functionaltest.
function M._sync()
  if M._in_context() then
    SnippetController.session:sync()
  end
end

---Expand snippet text.
---@param snippet_text string
function M.expand(snippet_text)
  if M._in_context() then
    SnippetController.session:merge(snippet_text)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  SnippetController.session = SnippetSession.new(bufnr, 'vim.snippet:' .. vim.loop.now())
  SnippetController.session:expand(snippet_text)

  local session = SnippetController.session ---@type vim.snippet.SnippetSession
  vim.api.nvim_buf_attach(bufnr, false, {
    on_lines = function()
      if session.disposed then
        return true
      end

      -- Avoid duplicate modification. (SnippetSession:sync also will modify the buffer contents).
      vim.schedule(function()
        session:sync()
      end)
    end,
  })
end

---Return jumpable for specified direction or not.
---@param direction vim.snippet.JumpDirection
---@return boolean
function M.jumpable(direction)
  if M._in_context() then
    return not not SnippetController.session:find_next_mark(direction)
  end
  return false
end

---Jump to next placeholder.
---@param direction vim.snippet.JumpDirection
function M.jump(direction)
  if M._in_context() then
    SnippetController.session:jump(direction)
  end
end

---Dispose current snippet session
function M.dispose()
  if M._in_context() then
    SnippetController.session:dispose()
    SnippetController.session = nil
  end
end

return M
