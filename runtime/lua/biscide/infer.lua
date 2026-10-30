-- What a missing name is, from how the code uses it (its syntax tree): a
-- function called (its parameters from the call's arguments, its results
-- from what takes them), a method called on the receiver, a struct built
-- (its fields from the literal's), a type. And, for Go, the names a
-- declaration uses that are defined nowhere: neither in it (parameters,
-- variables, type parameters), nor in its package (any of its files, the
-- generated ones too), nor built in. No language server is needed for it.

local source = require("biscide.source")

local M = {}

---@class biscide.Shape
---@field hint string "func", "method", "struct", "type"
---@field recv? string a method's type
---@field vars table<string, string> for the templates: params, results, fields

local GO_BUILTINS = {}
for w in ([[append cap clear close complex copy delete imag len make max min new panic print println real
  recover bool byte comparable complex64 complex128 error float32 float64 int int8 int16 int32 int64 rune
  string uint uint8 uint16 uint32 uint64 uintptr any true false iota nil]]):gmatch("%S+") do
  GO_BUILTINS[w] = true
end

local QUERY = [[
  (call_expression function: (identifier) @call)
  (call_expression function: (selector_expression operand: (identifier) @operand field: (field_identifier) @method))
  (composite_literal type: (type_identifier) @lit)
  (type_identifier) @type
  (parameter_declaration name: (identifier) @def)
  (variadic_parameter_declaration name: (identifier) @def)
  (short_var_declaration left: (expression_list (identifier) @def))
  (var_spec name: (identifier) @def)
  (const_spec name: (identifier) @def)
  (type_spec name: (type_identifier) @def)
  (range_clause left: (expression_list (identifier) @def))
  (type_parameter_declaration name: (identifier) @def)
  (method_declaration receiver: (parameter_list (parameter_declaration
    name: (identifier) @receiver
    type: [(pointer_type (type_identifier) @recvtype) (type_identifier) @recvtype])))
]]

local queries = {}
local function query(lang)
  if queries[lang] == nil then
    local ok, q = pcall(vim.treesitter.query.parse, lang, QUERY)
    queries[lang] = ok and q or false
  end
  return queries[lang] or nil
end

local function text(node, buf)
  return vim.treesitter.get_node_text(node, buf)
end

--- The enclosing function's parameters (name → type) and its results'
--- types as written.
local function enclosing(node, buf)
  local fn = node
  while fn and fn:type() ~= "function_declaration" and fn:type() ~= "method_declaration" and fn:type() ~= "func_literal" do
    fn = fn:parent()
  end
  local params, results = {}, nil
  if not fn then
    return params, results
  end
  local plist = fn:field("parameters")[1]
  for p in plist and plist:iter_children() or function() end do
    if p:type() == "parameter_declaration" or p:type() == "variadic_parameter_declaration" then
      local ty = p:field("type")[1]
      for _, name in ipairs(p:field("name")) do
        params[text(name, buf)] = ty and text(ty, buf) or "any"
      end
    end
  end
  local r = fn:field("result")[1]
  results = r and text(r, buf)
  return params, results
end

--- What an argument of a call is, as a parameter: its name and type.
local function param_of(arg, k, params, buf)
  local t = arg:type()
  local name, ty = "arg" .. k, "any"
  if t == "identifier" then
    name = text(arg, buf)
    ty = params[name] or "any"
  elseif t == "interpreted_string_literal" or t == "raw_string_literal" then
    ty = "string"
  elseif t == "int_literal" then
    ty = "int"
  elseif t == "float_literal" then
    ty = "float64"
  elseif t == "true" or t == "false" then
    ty = "bool"
  elseif t == "composite_literal" then
    local lt = arg:field("type")[1]
    ty = lt and text(lt, buf) or "any"
  elseif t == "unary_expression" and text(arg, buf):match("^&") then
    local inner = arg:field("operand")[1]
    local lt = inner and inner:type() == "composite_literal" and inner:field("type")[1]
    ty = lt and ("*" .. text(lt, buf)) or "any"
  elseif t == "selector_expression" then
    local f = arg:field("field")[1]
    name = f and text(f, buf):gsub("^%u", string.lower) or name
  end
  return name, ty
end

--- A call's results, from what takes them: `a, err := f()` two (the one
--- named err an error), `return f()` the enclosing function's, a
--- statement none, else one.
local function results_of(call, buf, enclosing_results)
  local parent = call:parent()
  if not parent then
    return ""
  end
  local pt = parent:type()
  if pt == "expression_statement" then
    return ""
  end
  if pt == "expression_list" then
    local stmt = parent:parent()
    local st = stmt and stmt:type()
    if (st == "short_var_declaration" or st == "assignment_statement") and stmt:field("right")[1] == parent then
      local left = stmt:field("left")[1]
      local types = {}
      for id in left:iter_children() do
        if id:named() then
          types[#types + 1] = text(id, buf) == "err" and "error" or "any"
        end
      end
      if #types == 1 then
        return " " .. types[1]
      end
      return " (" .. table.concat(types, ", ") .. ")"
    end
    if st == "return_statement" and parent:named_child_count() == 1 and enclosing_results then
      return " " .. enclosing_results
    end
  end
  return " any"
end

--- The shape of what `node` (a name used in the code) would declare.
---@param node TSNode the name
---@param kind string how it is used: "call", "method", "lit", "type"
---@param buf integer
---@param recv? string
---@return biscide.Shape
local function shape(node, kind, buf, recv)
  local vars = { params = "", results = "", fields = "" }
  if kind == "call" or kind == "method" then
    -- The call: the name's call_expression (for a method, through the
    -- selector).
    local call = node:parent()
    if kind == "method" then
      call = call and call:parent()
    end
    local params, enclosing_results = enclosing(node, buf)
    local args = call and call:field("arguments")[1]
    local list, k = {}, 0
    for a in args and args:iter_children() or function() end do
      if a:named() then
        k = k + 1
        local name, ty = param_of(a, k, params, buf)
        list[#list + 1] = name .. " " .. ty
      end
    end
    vars.params = table.concat(list, ", ")
    vars.results = call and results_of(call, buf, enclosing_results) or ""
    return { hint = kind == "method" and "method" or "func", recv = recv, vars = vars }
  elseif kind == "lit" then
    -- Its fields: the literal's keys, typed by their values.
    local lit = node:parent()
    local body = lit and lit:field("body")[1]
    local params = enclosing(node, buf)
    local fields = {}
    for el in body and body:iter_children() or function() end do
      if el:type() == "keyed_element" then
        local key, value = el:named_child(0), el:named_child(1)
        local name = key and text(key, buf)
        if name and name:match("^[%w_]+$") and value then
          local _, ty = param_of(value:named_child(0) or value, 0, params, buf)
          fields[#fields + 1] = name .. " " .. ty
        end
      end
    end
    vars.fields = #fields > 0 and (table.concat(fields, "\n\t") .. "\n\t") or ""
    return { hint = "struct", vars = vars }
  end
  return { hint = "struct", vars = vars }
end

-- ---- Go: what is defined in a package ----

--- The names a Go package declares at its top level (any of its files),
--- and its methods ("Type.name"); whether a file dot-imports.
---@param dir string
---@param tests boolean its test files too
local function package_names(dir, tests)
  local names, dot = {}, false
  for name, type in vim.fs.dir(dir) do
    if type == "file" and name:match("%.go$") and (tests or not name:match("_test%.go$")) then
      local block
      for _, line in ipairs(source.file(vim.fs.joinpath(dir, name))) do
        if line:match('^import%s+%.%s') or line:match('^%s+%.%s+"') then
          dot = true
        end
        local fn = line:match("^func%s+([%w_]+)")
        if fn then
          names[fn] = true
        end
        local recv, method = line:match("^func%s*%(%s*[%w_]*%s*%*?%s*([%w_]+)[^)]*%)%s*([%w_]+)")
        if recv then
          names[recv .. "." .. method] = true
        end
        local kw, rest = line:match("^(%a+)%s+(.*)")
        if kw == "type" or kw == "var" or kw == "const" then
          if rest:match("^%(") then
            block = true
          else
            for id in (rest:match("^([%w_][%w_%s,]*)") or ""):gmatch("[%w_]+") do
              names[id] = true
              if kw == "type" then
                break
              end
            end
          end
        elseif block then
          if line:match("^%)") then
            block = false
          else
            local ids = line:match("^%s+([%w_]+%s*,[%w_%s,]*)") or line:match("^%s+([%w_]+)")
            for id in (ids or ""):gmatch("[%w_]+") do
              names[id] = true
            end
          end
        end
      end
    end
  end
  return names, dot
end

--- Whether a struct `name` of the package has a field `field` (or embeds
--- something, which may have it).
local function struct_has(dir, name, field)
  for file, type in vim.fs.dir(dir) do
    if type == "file" and file:match("%.go$") then
      local inside = false
      for _, line in ipairs(source.file(vim.fs.joinpath(dir, file))) do
        if line:match("^type%s+" .. name .. "%s+struct") or line:match("^%s+" .. name .. "%s+struct%s*{") then
          inside = true
        elseif inside then
          if line:match("^}") then
            break
          end
          local first, second = line:match("^%s+%*?([%w_%.]+)%s*(%S*)")
          if first == field or (first and (second == "" or second:match("^`"))) then
            return true
          end
        end
      end
    end
  end
  return false
end

---@class biscide.Found
---@field name string
---@field row integer
---@field col integer
---@field shape biscide.Shape

--- The names Go node `n` uses that are defined nowhere, each with what it
--- would be.
---@param n table a graph node
---@param buf integer its file's buffer
---@return biscide.Found[]
function M.missing_go(n, buf)
  local ok, parser = pcall(vim.treesitter.get_parser, buf, "go")
  local q = query("go")
  if not (ok and parser and q) then
    return {}
  end
  local root = parser:parse()[1]:root()
  local dir = vim.fs.dirname(n.path)
  local pkg, dot = package_names(dir, n.path:match("_test%.go$") ~= nil)
  if dot then
    return {}
  end
  local defs, used, receiver, recvtype = {}, {}, nil, nil
  for id, node in q:iter_captures(root, buf, n.srow, n.erow + 1) do
    local cap = q.captures[id]
    if cap == "def" then
      defs[text(node, buf)] = true
    elseif cap == "receiver" then
      receiver = text(node, buf)
    elseif cap == "recvtype" then
      recvtype = text(node, buf)
    elseif cap == "type" then
      local parent = node:parent()
      if not (parent and parent:type() == "qualified_type") then
        used[#used + 1] = { node = node, kind = "type" }
      end
    elseif cap == "lit" then
      used[#used + 1] = { node = node, kind = "lit" }
    elseif cap == "call" then
      used[#used + 1] = { node = node, kind = "call" }
    elseif cap == "operand" then
      used[#used + 1] = { node = node, kind = "operand" }
    elseif cap == "method" then
      used[#used + 1] = { node = node, kind = "method" }
    end
  end
  local out, seen = {}, {}
  for k, u in ipairs(used) do
    local name = text(u.node, buf)
    local row, col = u.node:range()
    local missing = false
    if u.kind == "method" then
      -- A method called on the receiver its type has nowhere.
      local operand = used[k - 1]
      if operand and operand.kind == "operand" and receiver and text(operand.node, buf) == receiver and recvtype then
        missing = not pkg[recvtype .. "." .. name] and not struct_has(dir, recvtype, name)
      end
    elseif u.kind ~= "operand" then
      missing = not defs[name] and not pkg[name] and not GO_BUILTINS[name]
    end
    local key = (u.kind == "method" and recvtype and (recvtype .. ".") or "") .. name
    if missing and not seen[key] then
      seen[key] = true
      local kind = u.kind
      -- A type also built as a literal: a struct, with its fields.
      out[#out + 1] = {
        name = name,
        row = row,
        col = col,
        shape = shape(u.node, kind, buf, u.kind == "method" and recvtype or nil),
      }
    elseif missing and u.kind == "lit" then
      for _, f in ipairs(out) do
        if f.name == name then
          f.shape = shape(u.node, "lit", buf)
        end
      end
    end
  end
  return out
end

--- The shape of the name at `row`, `col` of Go buffer `buf` (a name the
--- language server says is missing).
---@return biscide.Shape?
function M.shape_at(buf, row, col)
  local ok, node = pcall(vim.treesitter.get_node, { bufnr = buf, pos = { row, col }, lang = "go" })
  if not (ok and node) then
    return nil
  end
  local parent = node:parent()
  local pt = parent and parent:type()
  if node:type() == "identifier" and pt == "call_expression" then
    return shape(node, "call", buf)
  elseif node:type() == "field_identifier" and pt == "selector_expression" then
    local call = parent:parent()
    if call and call:type() == "call_expression" then
      return shape(node, "method", buf)
    end
  elseif node:type() == "type_identifier" then
    if pt == "composite_literal" then
      return shape(node, "lit", buf)
    end
    return shape(node, "type", buf)
  end
end

return M
