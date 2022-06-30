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

local function empty() return "" end

local Snippet = {}
Snippet.__index = Snippet
function Snippet:__tostring()
  local text = {}
  for _, c in ipairs(self.children) do
    table.insert(text, tostring(c))
  end
  return table.concat(text, '')
end

---Create a new snippet.
---@param children (ast-node[]) Contents of the snippet.
---@return table |lsp-parser-snippet|
function Snippet.new(children)
  return setmetatable({
    type = node_type.SNIPPET,
    children = children
  }, Snippet)
end

local Tabstop = {}
Tabstop.__index = Tabstop
Tabstop.__tostring = empty

---Create a new tabstop.
---@param tabstop (number) Position of this tabstop.
---@param transform (table|nil) optional transform applied to the tabstop.
---@return table |lsp-parser-tabstop|
function Tabstop.new(tabstop, transform)
  return setmetatable({
    type = node_type.TABSTOP,
    tabstop = tabstop,
    transform = transform,
  }, Tabstop)
end

local Placeholder = {}
Placeholder.__index = Placeholder
function Placeholder:__tostring()
  local text = {}
  for _, c in ipairs(self.children or {}) do
    table.insert(text, tostring(c))
  end
  return table.concat(text, '')
end

---Create a new placeholder.
---@param tabstop (number) Position of the placeholder.
---@param children (ast-node[]) Content of the placeholder.
---@return table |lsp-parser-placeholder|
function Placeholder.new(tabstop, children)
  return setmetatable({
    type = node_type.PLACEHOLDER,
    tabstop = tabstop,
    children = children,
  }, Placeholder)
end

local Variable = {}
Variable.__index = Variable
Variable.__tostring = empty

---Create a new variable.
---@param name (string) Name.
---@param replacement (node[] | transform | nil)
---         - (node[]) Inserted when the variable is empty.
---         - (transform) Applied to the variable's value.
---@return table |lsp-parser-variable|
function Variable.new(name, replacement)
  local transform, children
  -- transform is an ast-node, children a flat list of nodes.
  if M.is_node(replacement) then
    transform = replacement
  else
    children = replacement
  end

  return setmetatable({
    type = node_type.VARIABLE,
    name = name,
    transform = transform,
    children = children,
  }, Variable)
end

local Choice = {}
Choice.__index = Choice
function Choice:__tostring()
  return self.items[1]
end

---Create a new choice.
---@param tabstop (number) Position of the choice.
---@param items (string[]) Choices.
---@return table |lsp-parser-choice|
function Choice.new(tabstop, items)
  return setmetatable({
    type = node_type.CHOICE,
    tabstop = tabstop,
    items = items,
  }, Choice)
end

local Transform = {}
Transform.__index = Transform
Transform.__tostring = empty

---Create a new transform.
---@param pattern (string) Regex applied to the variable/tabstop this transform
---                        is supplied to.
---@param format (table of Format|Text) Replacement for the regex.
---@param option (string|nil) Regex-options, default "".
---@return table |lsp-parser-transform|
function Transform.new(pattern, format, option)
  return setmetatable({
    type = node_type.TRANSFORM,
    pattern = pattern,
    format = format,
    option = option or '',
  }, Transform)
end

local Format = {}
Format.__index = Format
Format.__tostring = empty

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
function Format.new(capture_index, capture_transform)
  local if_text, else_text, modifier
  if type(capture_transform) == 'table' then
    if_text = capture_transform.if_text or ''
    else_text = capture_transform.else_text or ''
  elseif type(capture_transform) == 'string' then
    modifier = capture_transform
  end

  return setmetatable({
    type = node_type.FORMAT,
    capture_index = capture_index,
    modifier = modifier,
    if_text = if_text,
    else_text = else_text,
  }, Format)
end

local Text = {}
Text.__index = Text
function Text:__tostring()
  return self.esc
end

---Create new text.
---@param esc (string) Escaped text.
---@param raw (string|nil, default {esc}) Unescaped text.
---
---@return table |lsp-parser-text|
function Text.new(esc, raw)
  return setmetatable({
    type = node_type.TEXT,
    esc = esc,
    raw = raw or esc,
  }, Text)
end

M.Format = Format
M.Text = Text
M.Placeholder = Placeholder
M.Transform = Transform
M.Choice = Choice
M.Variable = Variable
M.Snippet = Snippet
M.Tabstop = Tabstop

local node_mts = {Format, Text, Placeholder, Transform, Choice, Variable, Snippet, Tabstop}

function M.is_node(t)
  return vim.tbl_contains(node_mts, getmetatable(t))
end

return M
