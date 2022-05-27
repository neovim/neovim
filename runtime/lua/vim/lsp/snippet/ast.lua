local M = {}

local node_type = {
  SNIPPET = 0,
  TABSTOP = 1,
  PLACEHOLDER = 2,
  VARIABLE = 3,
  CHOICE = 4,
  TRANSFORM = 5,
  FORMAT = 6,
  TEXT = 7,
}

M.node_type = node_type

local Node = {}
function Node:__tostring()
  local insert_text = {}
  if self.type == node_type.SNIPPET then
    for _, c in ipairs(self.children) do
      table.insert(insert_text, tostring(c))
    end
  elseif self.type == node_type.CHOICE then
    table.insert(insert_text, self.items[1])
  elseif self.type == node_type.PLACEHOLDER then
    for _, c in ipairs(self.children or {}) do
      table.insert(insert_text, tostring(c))
    end
  elseif self.type == node_type.TEXT then
    table.insert(insert_text, self.esc)
  end
  return table.concat(insert_text, '')
end

--- @private
local function new(t)
  return setmetatable(t, Node)
end

---Determine whether {t} is an AST-node.
---@param t table
---@return boolean
local function is_node(t)
  return getmetatable(t) == Node
end

M.is_node = is_node

---Create a new snippet.
---@param children (ast-node[]) Contents of the snippet.
---@return table |lsp-parser-snippet|
function M.snippet(children)
  return new({
    type = node_type.SNIPPET,
    children = children,
  })
end

---Create a new tabstop.
---@param tabstop (number) Position of this tabstop.
---@param transform (table|nil) optional transform applied to the tabstop.
---@return table |lsp-parser-tabstop|
function M.tabstop(tabstop, transform)
  return new({
    type = node_type.TABSTOP,
    tabstop = tabstop,
    transform = transform,
  })
end

---Create a new placeholder.
---@param tabstop (number) Position of the placeholder.
---@param children (ast-node[]) Content of the placeholder.
---@return table |lsp-parser-placeholder|
function M.placeholder(tabstop, children)
  return new({
    type = node_type.PLACEHOLDER,
    tabstop = tabstop,
    children = children,
  })
end

---Create a new variable.
---@param name (string) Name.
---@param replacement (node[] | transform | nil)
---         - (node[]) Inserted when the variable is empty.
---         - (transform) Applied to the variable's value.
---@return table |lsp-parser-variable|
function M.variable(name, replacement)
  local transform, children
  -- transform is an ast-node, children a flat list of nodes.
  if is_node(replacement) then
    transform = replacement
  else
    children = replacement
  end

  return new({
    type = node_type.VARIABLE,
    name = name,
    transform = transform,
    children = children,
  })
end

---Create a new choice.
---@param tabstop (number) Position of the choice.
---@param items (string[]) Choices.
---@return table |lsp-parser-choice|
function M.choice(tabstop, items)
  return new({
    type = node_type.CHOICE,
    tabstop = tabstop,
    items = items,
  })
end

---Create a new transform.
---@param pattern (string) Regex applied to the variable/tabstop this transform
---                        is supplied to.
---@param format (table of Format|Text) Replacement for the regex.
---@param option (string|nil) Regex-options, default "".
---@return table |lsp-parser-transform|
function M.transform(pattern, format, option)
  return new({
    type = node_type.TRANSFORM,
    pattern = pattern,
    format = format,
    option = option or '',
  })
end

---Create a new format which either inserts the capture at {capture_index},
---applies a modifier to the capture or inserts {if_text} if the capture is
---nonempty, and {else_text} otherwise.
---@param capture_index (number) Capture this format is applied to.
---@param capture_transform (string | table | nil)
---         - (string): {capture_transform} is a modifier.
---         - (table): {capture_transform} can contain either of
---                    - {if_text} (string, default "") Inserted for nonempty
---                                                     capture.
---                    - {else_text} (string, default "") Inserted for empty or
---                                                       undefined capture.
---@return table |lsp-parser-format|
function M.format(capture_index, capture_transform)
  local if_text, else_text, modifier
  if type(capture_transform) == 'table' then
    if_text = capture_transform.if_text or ''
    else_text = capture_transform.else_text or ''
  elseif type(capture_transform) == 'string' then
    modifier = capture_transform
  end

  return new({
    type = node_type.FORMAT,
    capture_index = capture_index,
    modifier = modifier,
    if_text = if_text,
    else_text = else_text,
  })
end

---Create new text.
---@param esc (string) Escaped text.
---@param raw (string|nil, default {esc}) Unescaped text.
---
---@return table |lsp-parser-text|
function M.text(esc, raw)
  return new({
    type = node_type.TEXT,
    esc = esc,
    raw = raw or esc,
  })
end

return M
