local lsp_snippet = require('vim.lsp._snippet')

---Feed keys.
---NOTE: This always enables `virtualedit=onemore`
---@param keys string
---@param mode string
local function feedkeys(keys, mode)
  local k = {}
  table.insert(k, '<Cmd>set virtualedit=onemore<CR>')
  table.insert(k, keys)
  table.insert(k, ('<Cmd>set virtualedit=%s<CR>'):format(vim.o.virtualedit))
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(table.concat(k), true, true, true), mode, true)
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
  local texts = vim.split(snippet_text, '\n', { plain = true })
  for i, text in ipairs(texts) do
    if i ~= #texts and string.match(text, '^%s*$') then
      -- Remove space only lines except the last line.
      table.insert(adjusted_snippet_text, '')
    else
      -- Adjust indent.
      if i ~= 1 then
        -- Change \t as one_indent.
        text = string.gsub(text, '^(\t+)', function(indent)
          return string.gsub(indent, '\t', one_indent)
        end)
        -- Add base_indent.
        table.insert(adjusted_snippet_text, base_indent .. text)
      else
        -- Use first line as-is.
        table.insert(adjusted_snippet_text, text)
      end
    end
  end
  return table.concat(adjusted_snippet_text, '\n')
end

---Get range from extmark.
---@param ns string
---@param mark_id number
---@return { s: number[], e: number[] }
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
---@param range { s: number[], e: number[] }
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
---NOTE: The `context.range` calculated by `tostring(node)`.
---@param snippet_node table
---@param callback fun(node: table, context: { depth: number, index: number, range: { s: number[], e: number[] }, parent?: table, replace: fun(new_node: table) }): table|nil
---@param cursor? number[]
local function traverse(snippet_node, callback, cursor)
  ---@param node table
  ---@param context { depth: number, index: number, range: { s: number[], e: number[] }, parent?: table, replace: fun(new_node: table) }
  ---@param cursor_ number[]
  local function traverse_recursive(node, context, cursor_)
    local s = { cursor_[1], cursor_[2] }
    if node.children then
      for i, child in ipairs(node.children) do
        traverse_recursive(child, {
          depth = context.depth + 1,
          index = i,
          parent = node,
          replace = (function(children, index)
            return function(new_node)
              children[index] = new_node
            end
          end)(node.children, i)
        }, cursor_)
      end
    else
      local texts = vim.split(tostring(node), '\n')
      cursor_[1] = cursor_[1] + #texts - 1
      cursor_[2] = #texts > 1 and #texts[#texts] or (cursor_[2] + #texts[1])
    end
    context.range = { s = s, e = { cursor_[1], cursor_[2] } }
    callback(node, context)
  end
  traverse_recursive(snippet_node, {
    depth = 0,
    index = 1,
    parent = nil,
    replace = function()
    end
  }, cursor or { 0, 0 })
end

---Select specific mark.
---@param mark vim.snippet.SnippetMark
local function select_mark(mark)
  local range = mark:get_range()
  if mark.node.type == lsp_snippet.Node.Type.Choice then
    feedkeys(([[<Esc><Cmd>call cursor(%s,%s)<CR>i]]):format(range.e[1] + 1, range.e[2] + 1), 'ni')
    vim.schedule(function()
      vim.fn.complete(range.s[2] + 1, mark.node.items)
    end)
  else
    if range.s[1] == range.e[1] and range.s[2] == range.e[2] then
      feedkeys(([[<Esc><Cmd>call cursor(%s,%s)<CR>i]]):format(range.e[1] + 1, range.e[2] + 1), 'ni')
    else
      feedkeys(([[<Esc><Cmd>call cursor(%s,%s)<CR>v<Cmd>call cursor(%s,%s)<CR><Esc>gvo<C-g>]]):format(
        range.s[1] + 1,
        range.s[2] + 1,
        range.e[1] + 1,
        range.e[2]
      ), 'ni')
    end
  end
end

---Resolve variables.
---NOTE: This function doesn't support fast-event.
---@param var_name string
---@return (number|string)?
local function resolve_variable(var_name)
  if var_name == 'TM_SELECTED_TEXT' then
    return ''
  elseif var_name == 'TM_CURRENT_LINE' then
    return vim.api.nvim_get_current_line()
  elseif var_name == 'TM_CURRENT_WORD' then
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line = vim.api.nvim_get_current_line()
    local before = string.sub(line, 1, cursor[2])
    local word_s = vim.regex([[\k\+$]]):match_str(before) or #before
    local word_after = string.sub(line, word_s + 1)
    local _, word_e = vim.regex([[^\k\+]]):match_str(word_after)
    return string.sub(line, word_s + 1, (word_e or word_s - 1) + 1)
  elseif var_name == 'TM_LINE_INDEX' then
    return vim.api.nvim_win_get_cursor(0)[2]
  elseif var_name == 'TM_LINE_NUMBER' then
    return vim.api.nvim_win_get_cursor(0)[2] + 1
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
---1. Normalize same tabstop nodes (e.g. `${1:foo} ${1:bar}` -> `${1:foo} ${1:foo}`)
---2. Resolve variables.
---3. Append 0-tabstop if not exist.
---4. Normalize tabstop order (0 tabstop will be a `max-tabstop + 1`).
---5. Make text to first insertion.
---@param snippet_text string
---@return { node: table, text: string, max_tabstop: number, min_tabstop: number }
local function analyze_snippet(snippet_text)
  local analyzed = {
    node = lsp_snippet.parse(snippet_text),
    text = '',
    min_tabstop = nil,
    max_tabstop = nil,
  }

  -- Normalize snippet nodes.
  local has_trailing_tabstop, origins = false, {}
  traverse(analyzed.node, function(node, context)
    if type(node.tabstop) == 'number' then
      local origin = origins[node.tabstop]
      if origin then
        context.replace(setmetatable(vim.tbl_deep_extend('keep', {}, origin), lsp_snippet.Node))
      else
        origins[node.tabstop] = node
      end
      has_trailing_tabstop = has_trailing_tabstop or node.tabstop == 0
      analyzed.min_tabstop = math.min(analyzed.min_tabstop or node.tabstop, node.tabstop)
      analyzed.max_tabstop = math.max(analyzed.max_tabstop or node.tabstop, node.tabstop)
    elseif lsp_snippet.Node.Type.Variable == node.type then
      local resolved = resolve_variable(node.name)
      context.replace(setmetatable({
        type = lsp_snippet.Node.Type.Text,
        raw = resolved,
        esc = resolved,
      }, lsp_snippet.Node))
    end
  end)
  analyzed.min_tabstop = analyzed.min_tabstop or 0
  analyzed.max_tabstop = analyzed.max_tabstop or 0

  -- Normalize tabstops.
  if not has_trailing_tabstop then
    table.insert(analyzed.node.children, setmetatable({
      type = lsp_snippet.Node.Type.Tabstop,
      tabstop = 0,
    }, lsp_snippet.Node))
  end
  traverse(analyzed.node, function(node)
    if node.tabstop == 0 then
      node.tabstop = analyzed.max_tabstop + 1
    end
  end)

  -- Create insertion text.
  traverse(analyzed.node, function(node)
    if vim.tbl_contains({
          lsp_snippet.Node.Type.Text,
          lsp_snippet.Node.Type.Choice,
        }, node.type) then
      analyzed.text = analyzed.text .. tostring(node)
    end
  end)

  return analyzed
end

---@class vim.snippet.SnippetController
---@field public session vim.snippet.SnippetSession
local SnippetController = {
  session = nil,
}

---@alias vim.snippet.JumpDirection "1" | "2"
local JumpDirection = {}
JumpDirection.Next = 1
JumpDirection.Prev = 2

---@class vim.snippet.SnippetMark
---@field public ns string
---@field public mark_id number
---@field public node table
---@field public origin table
---@field public text string
local SnippetMark = {}

---@param params { ns: string, mark_id: number, node: table, range: { s: number[], e: number[] }, origin: table }
function SnippetMark.new(params)
  local self = setmetatable({}, { __index = SnippetMark })
  self.ns = params.ns
  self.mark_id = params.mark_id
  self.node = params.node
  self.origin = params.origin
  self.text = get_text_by_range(get_range_from_mark(params.ns, params.mark_id))
  return self
end

---Get actual range from extmark.
---@return { s: number[], e: number[] }
function SnippetMark:get_range()
  return get_range_from_mark(self.ns, self.mark_id)
end

---Set range.
---@param range { s: number[], e: number[] }
function SnippetMark:set_range(range)
  vim.api.nvim_buf_set_extmark(0, self.ns, range.s[1], range.s[2], {
    id = self.mark_id,
    end_line = range.e[1],
    end_col = range.e[2],
    right_gravity = false,
    end_right_gravity = true,
  })
end

---Get text.
---@return string
function SnippetMark:get_text()
  return self.text
end

---Set text to the buffer.
---@param new_text string
function SnippetMark:set_text(new_text)
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
---@field public ns string
---@field public bufnr number
---@field public marks table
---@field public disposed boolean
---@field public changedtick number
---@field public saved_ranges table<number, table<number, { s: number[], e: number[] }>>
---@field public current_tabstop number
---@field public snippet_mark_ns number
---@field public snippet_mark_id number
local SnippetSession = {}

---Create SnippetSession instance.
---@param bufnr number
---@param namespace string
function SnippetSession.new(bufnr, namespace)
  local self = setmetatable({}, { __index = SnippetSession })
  self.ns = vim.api.nvim_create_namespace(namespace)
  self.bufnr = bufnr
  self.marks = {}
  self.disposed = false
  self.changedtick = 0
  self.saved_ranges = {}
  self.current_tabstop = 0
  self.snippet_mark_ns = vim.api.nvim_create_namespace(namespace .. ':snippet')
  self.snippet_mark_id = 0
  return self
end

---Expand snippet to the current buffer.
---@param snippet_text string
function SnippetSession:expand(snippet_text)
  local analyzed = analyze_snippet(adjust_indent(snippet_text))
  local texts = vim.split(analyzed.text, '\n')
  local cursor = vim.api.nvim_win_get_cursor(0)
  cursor[1] = cursor[1] - 1

  -- Insert normalized snippet text.
  vim.api.nvim_buf_set_text(0, cursor[1], cursor[2], cursor[1], cursor[2], texts)
  vim.api.nvim_win_set_cursor(0, { cursor[1] + 1, cursor[2] })

  -- Create extmarks.
  local marks, origins = {}, {}
  traverse(analyzed.node, function(node, context)
    if type(node.tabstop) == 'number' then
      table.insert(marks, SnippetMark.new({
        ns = self.ns,
        node = node,
        origin = origins[node.tabstop or -1],
        mark_id = vim.api.nvim_buf_set_extmark(self.bufnr, self.ns, context.range.s[1], context.range.s[2], {
          end_line = context.range.e[1],
          end_col = context.range.e[2],
          right_gravity = false,
          end_right_gravity = true,
        })
      }))
      origins[node.tabstop] = node
    end
  end, { cursor[1], cursor[2] })
  self.marks = marks

  -- Create snippet region marks.
  self.snippet_mark_id = vim.api.nvim_buf_set_extmark(self.bufnr, self.snippet_mark_ns, cursor[1], cursor[2], {
    end_line = cursor[1] + (#texts - 1),
    end_col = #texts > 1 and #texts[#texts] or cursor[2] + #texts[1],
    right_gravity = false,
    end_right_gravity = true,
  })

  -- Initialize.
  self.current_tabstop = analyzed.min_tabstop - 1
  self:sync()
end

---Jump to the suitable placeholder.
---@param direction vim.snippet.JumpDirection
function SnippetSession:jump(direction)
  local next_mark = self:find_next_mark(direction)
  if next_mark then
    self.current_tabstop = next_mark.node.tabstop
    select_mark(next_mark)
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
  if not self:within() then
    self:dispose()
    return
  end

  local changedtick = vim.api.nvim_buf_get_changedtick(0)
  if self.changedtick == changedtick then
    return
  end

  local changenr = vim.fn.changenr()

  -- Ignore undo/redo.
  local undotree = vim.fn.undotree()
  if undotree.seq_last ~= undotree.seq_cur then
    for _, mark in ipairs(self.marks) do
      mark:set_text(get_text_by_range(mark:get_range()))
      if self.saved_ranges[changenr] and self.saved_ranges[changenr][mark.mark_id] then
        mark:set_range(self.saved_ranges[changenr][mark.mark_id])
      end
    end
    self.changedtick = changedtick
    return
  end

  --- Save current mark ranges.
  self.saved_ranges[changenr] = {}
  for _, mark in ipairs(self.marks) do
    self.saved_ranges[changenr][mark.mark_id] = mark:get_range()
  end

  -- Dispose directly modified non-origin marks.
  for i = #self.marks, 1, -1 do
    local mark = self.marks[i]
    if mark.origin then
      if mark:get_text() ~= get_text_by_range(mark:get_range()) then
        table.remove(self.marks, i)
        mark:dispose()
      end
    end
  end

  -- Sync non-origin marks.
  local origins = {}
  for _, mark in ipairs(self.marks) do
    origins[mark.node.tabstop] = origins[mark.node.tabstop] or mark
    if mark == origins[mark.node.tabstop] then
      mark:set_text(get_text_by_range(mark:get_range()))
    else
      mark:set_text(origins[mark.node.tabstop]:get_text())
    end
    mark:sync()
  end

  self.changedtick = changedtick
end

---Return the cursor is within the snippet range or not.
---@return boolean
function SnippetSession:within()
  if self.disposed then
    return false
  end

  if self.bufnr ~= vim.api.nvim_get_current_buf() then
    return false
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  cursor[1] = cursor[1] - 1

  local range = get_range_from_mark(self.snippet_mark_ns, self.snippet_mark_id)
  if cursor[1] < range.s[1] or (cursor[1] == range.s[1] and cursor[2] < range.s[2]) then
    return false
  end
  if range.e[1] < cursor[1] or (range.e[1] == cursor[1] and range.e[2] < cursor[2]) then
    return false
  end
  return true
end

---Dispose snippet session.
function SnippetSession:dispose()
  for _, mark in ipairs(self.marks) do
    mark:dispose()
  end
  vim.api.nvim_buf_del_extmark(self.bufnr, self.snippet_mark_ns, self.snippet_mark_id)
  self.disposed = true
end

local M = {}

M.JumpDirection = JumpDirection

---Expand snippet text.
---@param snippet_text string
function M.expand(snippet_text)
  if SnippetController.session then
    SnippetController.session:dispose()
  end

  local bufnr = vim.api.nvim_get_current_buf()
  SnippetController.session = SnippetSession.new(bufnr, 'vim.snippet:' .. vim.loop.now())
  SnippetController.session:expand(snippet_text)
  SnippetController.session:jump(M.JumpDirection.Next)

  local session = SnippetController.session
  vim.api.nvim_buf_attach(bufnr, false, {
    on_lines = function()
      if session.disposed then
        return true
      end
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
  if not SnippetController.session or SnippetController.session.disposed then
    return false
  end
  return not not SnippetController.session:find_next_mark(direction)
end

---Jump to next placeholder.
---@param direction vim.snippet.JumpDirection
function M.jump(direction)
  if not SnippetController.session or SnippetController.session.disposed then
    return
  end
  SnippetController.session:jump(direction)
end

---Sync current modification.
function M.sync()
  if not SnippetController.session or SnippetController.session.disposed then
    return
  end
  SnippetController.session:sync()
end

---Dispose current snippet session
function M.dispose()
  if not SnippetController.session or SnippetController.session.disposed then
    return
  end
  SnippetController.session:dispose()
  SnippetController.session = nil
end

return M
