-- A file's outline from its parse tree: its declarations (top level; a
-- Rust `impl`'s and `trait`'s functions as methods; a Rust `mod`'s items),
-- the names each one uses, and the file's imports (Go) or `use`s (Rust).
-- Test modules (`mod tests`, `#[cfg(test)]`) are left out.
--
-- And its parts: every line of the file in exactly one of them, each a
-- card of biscide's. A declaration's part starts at its doc comment and
-- attributes; the package clause, the imports, a comment standing on its
-- own and any code left (a Rust `impl … {` and its `}`) are parts of their
-- own: nothing of the file is in no card.
--
-- A declaration: { name, receiver?, kind, srow, scol, erow, ecol, nrow,
-- ncol (its name's start), refs = { { q?, name, role } } }; roles: "call",
-- "signature", "field", "body".

local M = {}

local function text(node, src)
  return vim.treesitter.get_node_text(node, src)
end

local function field(node, name)
  local f = node:field(name)
  return f and f[1] or nil
end

local function children(node)
  local out = {}
  for child in node:iter_children() do
    out[#out + 1] = child
  end
  return out
end

--- The first descendant (or itself) of a type in `types`.
local function find(node, types)
  if types[node:type()] then
    return node
  end
  for _, c in ipairs(children(node)) do
    local f = find(c, types)
    if f then
      return f
    end
  end
end

-- ---- The names a declaration uses ----

--- The role of a declaration's part, by its field: its name and receiver
--- are not uses; its parameters and results are its signature.
local function part_role(fieldname)
  if fieldname == "name" or fieldname == "receiver" then
    return nil
  end
  if fieldname == "parameters" or fieldname == "result" or fieldname == "return_type"
    or fieldname == "type_parameters" then
    return "signature"
  end
  return "body"
end

--- A qualified name, when `n` is one (`pkg.Name`, `a::b::Name`,
--- `value.method`): its qualifier and name; its operand is not looked into.
local function qualified(n, src, lang)
  local t = n:type()
  local q, name
  if lang == "go" and t == "selector_expression" then
    q, name = field(n, "operand"), field(n, "field")
  elseif lang == "go" and t == "qualified_type" then
    q, name = field(n, "package"), field(n, "name")
  elseif lang == "rust" and (t == "scoped_identifier" or t == "scoped_type_identifier") then
    q, name = field(n, "path"), field(n, "name")
  elseif lang == "rust" and t == "field_expression" then
    q, name = field(n, "value"), field(n, "field")
  else
    return nil
  end
  if not q or not name then
    return nil
  end
  local qt = q:type()
  local qualifier
  if lang == "go" and (qt == "identifier" or qt == "package_identifier") then
    qualifier = text(q, src)
  elseif lang == "rust" and t:sub(1, 6) == "scoped" then
    qualifier = vim.split(text(q, src), "::", { plain = true })[1]
  else
    -- A method of a value made by an expression: its type is unknown.
    qualifier = "."
  end
  return { q = qualifier, name = text(name, src), role = "body" }
end

local function refs(n, src, lang)
  local out, stack = {}, {}
  for child, fieldname in n:iter_children() do
    local role = part_role(fieldname)
    if role then
      table.insert(stack, 1, { child, role })
    end
  end
  while #stack > 0 do
    local node, role = unpack(table.remove(stack))
    local r = qualified(node, src, lang)
    local t = node:type()
    if r then
      r.role = role
      out[#out + 1] = r
    elseif t == "identifier" or t == "type_identifier" then
      out[#out + 1] = { name = text(node, src), role = role }
    else
      local inner = role
      if (t == "field_declaration_list" or t == "enum_variant_list") and role == "body" then
        inner = "field"
      end
      local callee = t == "call_expression" and field(node, "function") or nil
      local kids = children(node)
      for k = #kids, 1, -1 do
        local c = kids[k]
        stack[#stack + 1] = { c, (callee and c:id() == callee:id()) and "call" or inner }
      end
    end
  end
  return out
end

local function push(out, name, whole, kind, receiver, src, lang)
  local sr, sc, er, ec = whole:range()
  local nr, nc = name:range()
  out.decls[#out.decls + 1] = {
    name = text(name, src),
    receiver = receiver,
    kind = kind,
    srow = sr, scol = sc, erow = er, ecol = ec,
    nrow = nr, ncol = nc,
    refs = refs(whole, src, lang),
  }
end

-- ---- Go ----

local function go_named(n, kind, receiver, src, out)
  local name = field(n, "name")
  if name then
    push(out, name, n, kind, receiver, src, "go")
  end
end

local function go_specs(n, kinds, src, out, block)
  if not block then
    local sr, _, er, ec = n:range()
    block = { srow = sr, erow = (ec == 0 and er > sr) and er - 1 or er }
  end
  for _, c in ipairs(children(n)) do
    if not kinds[c:type()] then
      go_specs(c, kinds, src, out, block)
    else
      local tt = field(c, "type")
      tt = tt and tt:type()
      local kind
      if c:type() == "var_spec" then
        kind = "var"
      elseif c:type() == "const_spec" then
        kind = "const"
      elseif tt == "struct_type" then
        kind = "struct"
      elseif tt == "interface_type" then
        kind = "interface"
      else
        kind = "type"
      end
      -- `var a, b = …`: each name is a declaration of the whole spec.
      for _, name in ipairs(c:field("name")) do
        push(out, name, c, kind, nil, src, "go")
        out.decls[#out.decls].block = block
      end
    end
  end
end

local function go_imports(n, src, out)
  for _, c in ipairs(children(n)) do
    if c:type() ~= "import_spec" then
      go_imports(c, src, out)
    else
      local path = field(c, "path")
      if path then
        local p = text(path, src):gsub('^"', ""):gsub('"$', "")
        local alias = field(c, "name")
        alias = alias and text(alias, src) or p:match("([^/]+)$") or p
        out.imports[#out.imports + 1] = { alias = alias, path = p }
      end
    end
  end
end

--- A node's rows (from 0, the last one included).
local function rows(n)
  local sr, _, er, ec = n:range()
  return sr, (ec == 0 and er > sr) and er - 1 or er
end

local function go_file(root, src, out)
  for _, n in ipairs(children(root)) do
    local t = n:type()
    if t == "package_clause" then
      local sr, er = rows(n)
      local name = n:named_child(0)
      out.parts[#out.parts + 1] = {
        kind = "package",
        name = "package " .. (name and text(name, src) or ""),
        srow = sr,
        erow = er,
      }
    elseif t == "import_declaration" then
      local sr, er = rows(n)
      out.import_rows[#out.import_rows + 1] = { sr, er }
      go_imports(n, src, out)
    elseif t == "function_declaration" then
      go_named(n, "func", nil, src, out)
    elseif t == "method_declaration" then
      local recv = field(n, "receiver")
      local ty = recv and find(recv, { type_identifier = true })
      go_named(n, "method", ty and text(ty, src) or nil, src, out)
    elseif t == "type_declaration" then
      go_specs(n, { type_spec = true, type_alias = true }, src, out)
    elseif t == "var_declaration" then
      go_specs(n, { var_spec = true }, src, out)
    elseif t == "const_declaration" then
      go_specs(n, { const_spec = true }, src, out)
    end
  end
end

-- ---- Rust ----

local rust_items

local function is_test_attribute(n, src)
  return n:type() == "attribute_item" and text(n, src):gsub(" ", ""):find("cfg(test)", 1, true) ~= nil
end

--- The names a use tree ends in (`a::{b, c::d as e}` → b, e).
local function use_leaves(n, src, out)
  local t = n:type()
  if t == "identifier" or t == "type_identifier" then
    out[#out + 1] = text(n, src)
  elseif t == "scoped_identifier" then
    local name = field(n, "name")
    if name then
      out[#out + 1] = text(name, src)
    end
  elseif t == "scoped_use_list" then
    local list = field(n, "list")
    if list then
      use_leaves(list, src, out)
    end
  elseif t == "use_as_clause" then
    local alias = field(n, "alias")
    if alias then
      out[#out + 1] = text(alias, src)
    end
  else
    for _, c in ipairs(children(n)) do
      use_leaves(c, src, out)
    end
  end
end

local ITEM_KINDS = {
  function_item = "func",
  struct_item = "struct",
  union_item = "struct",
  enum_item = "enum",
  trait_item = "interface",
  type_item = "type",
  const_item = "const",
  static_item = "const",
}

local function rust_item(item, src, owner, out)
  local t = item:type()
  if t == "impl_item" then
    local ty = field(item, "type")
    ty = ty and find(ty, { type_identifier = true })
    local body = field(item, "body")
    if body then
      rust_items(body, src, ty and text(ty, src) or nil, out)
    end
    return
  elseif t == "mod_item" then
    local name = field(item, "name")
    if name and text(name, src) == "tests" then
      return
    end
    local body = field(item, "body")
    if body then
      rust_items(body, src, nil, out)
    end
    return
  elseif t == "use_declaration" then
    local sr, er = rows(item)
    out.import_rows[#out.import_rows + 1] = { sr, er }
    local arg = field(item, "argument")
    if not arg then
      return
    end
    local head = vim.trim(vim.split(text(arg, src), "::", { plain = true })[1])
    local names = {}
    use_leaves(arg, src, names)
    for _, alias in ipairs(names) do
      out.imports[#out.imports + 1] = { alias = alias, path = head .. "::" .. alias }
    end
    return
  elseif t == "declaration_list" then
    return rust_items(item, src, owner, out)
  end
  local kind
  if (t == "function_item" or t == "function_signature_item") and owner then
    kind = "method"
  else
    kind = ITEM_KINDS[t]
  end
  if not kind then
    return
  end
  local name = field(item, "name")
  if not name then
    return
  end
  push(out, name, item, kind, owner, src, "rust")
  if t == "trait_item" then
    local body = field(item, "body")
    if body then
      rust_items(body, src, text(name, src), out)
    end
  end
end

rust_items = function(n, src, owner, out)
  local items = children(n)
  for k, item in ipairs(items) do
    if not (k > 1 and is_test_attribute(items[k - 1], src)) then
      rust_item(item, src, owner, out)
    end
  end
end

-- ---- Parts: every line in one ----

local COMMENT = { "^%s*//", "^%s*/%*", "^%s*%*", "^%s*#%[", "^%s*#!%[" }

---@param line string?
local function is_comment(line)
  if not line then
    return false
  end
  for _, p in ipairs(COMMENT) do
    if line:find(p) then
      return true
    end
  end
  return false
end

local function is_blank(line)
  return line == nil or line:find("^%s*$") ~= nil
end

--- What a comment says, for a card's title.
local function gist(line)
  local t = vim.trim((line or ""):gsub("^%s*[/%*#!%[]+", ""):gsub("%*/%s*$", ""))
  return #t > 48 and (t:sub(1, 47) .. "…") or t
end

--- The parts of a file: `out.decls` given their own (each extended up over
--- its doc comment and attributes; a declaration holding others, a Rust
--- trait, keeps only its lines before them), the package clause and the
--- imports theirs, and the lines left (each run of them between blank
--- lines) parts of their own, "comment" or "code".
---@param lines string[]
local function cover(lines, out)
  local owner = {} -- row → its part
  local function own(part, from, to)
    for r = from, to do
      owner[r] = owner[r] or part
    end
  end
  -- A declaration holding others (a Rust trait) keeps its lines before
  -- the first of them; Go's grouped specs share their block's first and
  -- last lines.
  local decls = out.decls
  for _, d in ipairs(decls) do
    d.erow = (d.ecol == 0 and d.erow > d.srow) and d.erow - 1 or d.erow
  end
  for _, d in ipairs(decls) do
    for _, inner in ipairs(decls) do
      if inner ~= d and inner.srow > d.srow and inner.erow <= d.erow then
        d.erow = math.min(d.erow, inner.srow - 1)
      end
    end
  end
  local blocks = {}
  for _, d in ipairs(decls) do
    if d.block then
      local b = blocks[d.block] or { first = d, last = d }
      if d.srow < b.first.srow then
        b.first = d
      end
      if d.srow > b.last.srow then
        b.last = d
      end
      blocks[d.block] = b
    end
  end
  for block, b in pairs(blocks) do
    b.first.srow = block.srow
    b.last.erow = block.erow
  end
  for _, d in ipairs(decls) do
    own(d, d.srow, d.erow)
  end
  -- The imports: one part of each run of them.
  table.sort(out.import_rows, function(a, b)
    return a[1] < b[1]
  end)
  local imports = {}
  for _, r in ipairs(out.import_rows) do
    local last = imports[#imports]
    local between_blank = last and (function()
      for k = last.erow + 1, r[1] - 1 do
        if not is_blank(lines[k + 1]) then
          return false
        end
      end
      return true
    end)()
    if last and between_blank and r[1] - last.erow <= 2 then
      last.erow = r[2]
    else
      imports[#imports + 1] = { kind = "imports", name = "imports", srow = r[1], erow = r[2] }
    end
  end
  vim.list_extend(out.parts, imports)
  for _, p in ipairs(out.parts) do
    own(p, p.srow, p.erow)
  end
  -- Each part extended up over the comments and attributes right above it.
  local function extend_up(part)
    while part.srow > 0 and not owner[part.srow - 1] and is_comment(lines[part.srow]) do
      part.srow = part.srow - 1
      owner[part.srow] = part
    end
  end
  for _, d in ipairs(decls) do
    extend_up(d)
  end
  for _, p in ipairs(out.parts) do
    extend_up(p)
  end
  -- What is left: a part of each run of lines between blank ones.
  local r = 0
  while r < #lines do
    if owner[r] or is_blank(lines[r + 1]) then
      r = r + 1
    else
      local from, all_comment = r, true
      while r < #lines and not owner[r] and not is_blank(lines[r + 1]) do
        all_comment = all_comment and is_comment(lines[r + 1])
        r = r + 1
      end
      local first = lines[from + 1]
      out.parts[#out.parts + 1] = {
        kind = all_comment and "comment" or "code",
        name = all_comment and gist(first) or vim.trim(first),
        srow = from,
        erow = r - 1,
      }
    end
  end
  table.sort(out.parts, function(a, b)
    return a.srow < b.srow
  end)
  -- The file's blank lines at its end are its last part's (typed past its
  -- last line, the card has them). The text's last line is no line when
  -- the text ends with a line break.
  local count = (lines[#lines] == "" and #lines > 1) and #lines - 1 or #lines
  local last
  for _, list in ipairs({ decls, out.parts }) do
    for _, p in ipairs(list) do
      if not last or p.erow > last.erow then
        last = p
      end
    end
  end
  if last and last.erow < count - 1 then
    for r = last.erow + 1, count - 1 do
      if not is_blank(lines[r + 1]) then
        return
      end
    end
    last.erow = count - 1
  end
end

--- The outline of `src` (a string) in `lang` ("go" or "rust").
function M.outline(src, lang)
  local out = { decls = {}, imports = {}, parts = {}, import_rows = {} }
  local ok, parser = pcall(vim.treesitter.get_string_parser, src, lang)
  if not ok then
    return out
  end
  local tree = parser:parse()[1]
  if not tree then
    return out
  end
  local root = tree:root()
  if lang == "go" then
    go_file(root, src, out)
  elseif lang == "rust" then
    rust_items(root, src, nil, out)
  end
  cover(vim.split(src, "\n", { plain = true }), out)
  return out
end

return M
