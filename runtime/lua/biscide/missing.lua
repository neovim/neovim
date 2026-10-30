-- What the active declaration names that is nowhere: the names its
-- language server says are undefined (gopls: "undefined: x", "x.m
-- undefined (type T has no field or method m)"; rustc and rust-analyzer:
-- "cannot find function `x` in this scope", "no method named `m` found for
-- struct `S`", …), and in Go those biscide finds itself (biscide.infer: no
-- language server needed), each with what it is from how it is used. Each gets a card in the uses lane (a red link from the
-- name). Resolving one (a click on its card, `gm` on the name) offers, in
-- a picker: the language server's quick fixes, a declaration of the
-- program of that name to import, a new one of any kind written from
-- scratch, or from a template (biscide.templates), in the active file.

local Cards = require("biscide.cards")
local State = require("biscide.state")
local templates = require("biscide.templates")

local M = {}

---@class biscide.Missing
---@field name string
---@field hint? string what it seems to be: "func", "type", "value", "module", "method"
---@field recv? string the type a missing method is of
---@field qual? string the package it was asked of (Go's `pkg.Name`)
---@field row integer where it is first named (the file's row, from 0)
---@field col integer
---@field message string
---@field diagnostics vim.Diagnostic[]
---@field vars? table<string, string> what the code says it takes, gives, has (biscide.infer)

--- The messages that say a name is undefined: a pattern, and what its
--- captures are.
local PATTERNS = {
  -- Go.
  { "^undefined: ([%w_]+)%.([%w_]+)$", { "qual", "name" } },
  { "^undefined: ([%w_]+)$", { "name" } },
  { "^[%w_%.%(%)]+%.([%w_]+) undefined %(type %*?([%w_%.%[%]]+) has no field or method", { "name", "recv" }, "method" },
  -- Rust.
  { "cannot find (%a+) `([^`]+)` in this scope", { "hint", "name" } },
  { "use of undeclared type `([^`]+)`", { "name" }, "type" },
  { "use of undeclared crate or module `([^`]+)`", { "name" }, "module" },
  { "unresolved import `([^`]+)`", { "name" }, "module" },
  { "no method named `([^`]+)` found for %a+ `([^`]+)`", { "name", "recv" }, "method" },
  { "no function or associated item named `([^`]+)` found for %a+ `([^`]+)`", { "name", "recv" }, "method" },
}

local HINTS = { ["function"] = "func", value = "value", type = "type", struct = "type", trait = "type", macro = "func" }

--- What a diagnostic says is missing, if it says so.
---@param d vim.Diagnostic
---@return table?
local function parse(d)
  local msg = d.message:match("^[^\n]*")
  for _, p in ipairs(PATTERNS) do
    local caps = { msg:match(p[1]) }
    if caps[1] then
      local out = { hint = p[3] }
      for k, field in ipairs(p[2]) do
        out[field] = caps[k]
      end
      out.hint = HINTS[out.hint] or out.hint
      -- `a::b::C`: the last name; a method's type without its generics.
      out.name = out.name:match("([%w_]+)$") or out.name
      out.recv = out.recv and (out.recv:match("([%w_]+)[^%w_]*$") or out.recv)
      return out
    end
  end
end

--- What a name seems to be from how the code uses it: called, built, or
--- asked a path of.
local function guess(line, col, name)
  local after = line:sub(col + #name + 1):match("^%s*(.?.?)")
  if after:sub(1, 1) == "(" then
    return "func"
  elseif after:sub(1, 1) == "{" or after == "::" then
    return "type"
  end
end

--- The names node `n`'s code has that are nowhere, in the order it has them.
---@param n table a graph node
---@return biscide.Missing[]
function M.of(n)
  local buf = vim.fn.bufnr(n.path)
  if buf == -1 or not vim.api.nvim_buf_is_loaded(buf) then
    return {}
  end
  local by_name, out = {}, {}
  local diags = vim.diagnostic.get(buf, { severity = vim.diagnostic.severity.ERROR })
  table.sort(diags, function(a, b)
    if a.lnum ~= b.lnum then
      return a.lnum < b.lnum
    end
    return a.col < b.col
  end)
  for _, d in ipairs(diags) do
    local m = d.lnum >= n.srow and d.lnum <= n.erow and parse(d)
    if m then
      local key = (m.recv and (m.recv .. ".") or "") .. m.name
      local item = by_name[key]
      if not item then
        local line = vim.api.nvim_buf_get_lines(buf, d.lnum, d.lnum + 1, false)[1] or ""
        local s = line:find(m.name, d.col + 1, true)
        item = {
          name = m.name,
          hint = m.hint ~= "value" and m.hint or guess(line, s and s - 1 or d.col, m.name) or m.hint,
          recv = m.recv,
          qual = m.qual,
          row = d.lnum,
          col = s and s - 1 or d.col,
          message = d.message:match("^[^\n]*"),
          diagnostics = {},
        }
        by_name[key] = item
        out[#out + 1] = item
      end
      table.insert(item.diagnostics, d)
    end
  end
  -- Go: what biscide finds itself (the language server may be away, or not
  -- have looked yet), and what each is from how the code uses it.
  if templates.lang(n.path) == "go" then
    local infer = require("biscide.infer")
    for _, f in ipairs(infer.missing_go(n, buf)) do
      local key = (f.shape.recv and (f.shape.recv .. ".") or "") .. f.name
      if not by_name[key] then
        local item = {
          name = f.name,
          recv = f.shape.recv,
          row = f.row,
          col = f.col,
          message = (f.shape.recv and (f.shape.recv .. "." .. f.name) or f.name) .. " is defined nowhere",
          diagnostics = {},
        }
        by_name[key] = item
        out[#out + 1] = item
      end
    end
    for _, item in ipairs(out) do
      local shape = infer.shape_at(buf, item.row, item.col)
      if shape then
        item.hint = shape.hint
        item.recv = item.recv or shape.recv
        item.vars = shape.vars
      end
    end
    table.sort(out, function(a, b)
      if a.row ~= b.row then
        return a.row < b.row
      end
      return a.col < b.col
    end)
  end
  return out
end

--- The names a template is filled with for missing name `m`.
---@param m biscide.Missing
local function vars_of(m)
  return vim.tbl_extend("force", m.vars or {}, { name = m.name, recv = m.recv })
end

-- ---- Their cards ----

---@type table<integer, biscide.Missing> the missing names shown, by their cards' ids (negative)
M.shown = {}
---@type table<string, integer> each card's buffer
local bufs = {}

local function card_buf(key, lines)
  local buf = bufs[key]
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = "hide"
    bufs[key] = buf
  end
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  return buf
end

local ns = vim.api.nvim_create_namespace("biscide_missing")

--- The cards of what node `n` names that is nowhere: each its card (a
--- scratch buffer saying so), its node's info for the GUI, its link.
---@param n table
---@param view { max_rows: integer, cols: integer }
---@param again? boolean the names found last time (the code is being typed)
---@return { id: integer, card: biscide.Card, info: table, link: table }[]
function M.cards(n, view, again)
  local list = (again and M.last and M.last.node == n.id) and M.last.list or M.of(n)
  M.last = { node = n.id, list = list }
  M.shown = {}
  local out = {}
  for k, m in ipairs(list) do
    local id = -k
    M.shown[id] = m
    local key = ("missing:%s:%s:uses"):format(n.rel, (m.recv and (m.recv .. ".") or "") .. m.name)
    local lines = { m.message, "", "Click, or gm on the name: import it, create it, from a template" }
    local buf = card_buf(key, lines)
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, { end_row = 1, hl_group = "DiagnosticError" })
    vim.api.nvim_buf_set_extmark(buf, ns, 2, 0, { end_row = 3, hl_group = "Comment" })
    local card = State.cards:place(key, buf, 0, #lines - 1, view, "uses", nil, Cards.PLAIN)
    out[#out + 1] = {
      id = id,
      card = card,
      info = {
        id = id,
        name = m.recv and (m.recv .. "." .. m.name) or m.name,
        short = m.name,
        kind = "missing",
        rel = n.rel,
        line = m.row + 1,
        lines = #lines,
        used_by = 1,
        uses = 0,
        layer = vim.NIL,
      },
      link = { node = id, column = "uses", kinds = {}, violation = true, row = m.row, col = m.col },
    }
  end
  return out
end

-- ---- Resolving one ----

--- A code action applied (resolved first when it has to be).
local function apply(action, client)
  if not action.edit and not action.command and client:supports_method("codeAction/resolve") then
    client:request("codeAction/resolve", action, function(_, resolved)
      if resolved then
        apply(resolved, client)
      end
    end)
    return
  end
  if action.edit then
    vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
  end
  local cmd = action.command
  if type(cmd) == "table" then
    client:exec_cmd(cmd)
  elseif type(cmd) == "string" then
    client:exec_cmd(action)
  end
end

--- The code actions of `kind` the language servers offer for `buf`'s
--- `range` (and its diagnostics); `cb` with them ({ action, client }).
local function code_actions(buf, range, diagnostics, only, cb)
  local params = function(client)
    local lsp = {}
    for _, d in ipairs(diagnostics) do
      local o = d.user_data and d.user_data.lsp
      if o then
        lsp[#lsp + 1] = o
      end
    end
    return {
      textDocument = vim.lsp.util.make_text_document_params(buf),
      range = range,
      context = { diagnostics = lsp, only = only },
    }
  end
  vim.lsp.buf_request_all(buf, "textDocument/codeAction", params, function(results)
    local out = {}
    for client_id, r in pairs(results) do
      local client = vim.lsp.get_client_by_id(client_id)
      for _, action in ipairs(client and r.result or {}) do
        out[#out + 1] = { action = action, client = client }
      end
    end
    cb(out)
  end)
end

local function range_of(m)
  return {
    start = { line = m.row, character = m.col },
    ["end"] = { line = m.row, character = m.col + #m.name },
  }
end

--- Go: the package a file is in (its package clause).
local function go_package(path)
  for _, line in ipairs(vim.fn.readfile(path, "", 50)) do
    local p = line:match("^package%s+([%w_]+)")
    if p then
      return p
    end
  end
end

--- Rust: a file's module path in its crate (`src/a/b.rs`: `crate::a::b`).
local function rust_module(rel)
  local inner = rel:match("src/(.*)%.rs$")
  if not inner then
    return "crate"
  end
  local parts = vim.split(inner, "/", { plain = true })
  local last = parts[#parts]
  if last == "mod" or last == "lib" or last == "main" then
    table.remove(parts)
  end
  return table.concat(vim.list_extend({ "crate" }, parts), "::")
end

--- Declaration `d` of the program imported where `m` is named in node
--- `n`'s file: Go names it by its package (the import added by the
--- language server's organize imports); Rust `use`s it.
local function import(m, n, d)
  local buf = Cards.buffer(n.path)
  if templates.lang(n.path) == "go" then
    local pkg = go_package(d.path)
    if not pkg or vim.fs.dirname(d.path) == vim.fs.dirname(n.path) then
      return require("biscide.view").notice(d.name .. " is in this package already.")
    end
    for _, diag in ipairs(m.diagnostics) do
      local line = vim.api.nvim_buf_get_lines(buf, diag.lnum, diag.lnum + 1, false)[1] or ""
      local s = line:find(m.name, diag.col + 1, true)
      if s and not line:sub(1, s - 1):match("%.$") then
        vim.api.nvim_buf_set_text(buf, diag.lnum, s - 1, diag.lnum, s - 1, { pkg .. "." })
      end
    end
    local whole = { start = { line = 0, character = 0 }, ["end"] = { line = vim.api.nvim_buf_line_count(buf), character = 0 } }
    code_actions(buf, whole, {}, { "source.organizeImports" }, function(actions)
      if actions[1] then
        apply(actions[1].action, actions[1].client)
      end
    end)
  else
    local use = ("use %s::%s;"):format(rust_module(d.rel), d.short)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, math.min(200, vim.api.nvim_buf_line_count(buf)), false)
    local at = 0
    for k, line in ipairs(lines) do
      if line:match("^use ") or line:match("^//!") then
        at = k
      end
    end
    vim.api.nvim_buf_set_lines(buf, at, at, false, { use })
  end
end

--- A declaration started from template `t` for `m`: written at the end of
--- the active file, in the new card.
local function create(t, m)
  local lines, at = templates.expand(t, vars_of(m))
  require("biscide.navigate").new(lines, at)
end

--- What a missing name can start from, in a picker: your templates and
--- biscide's.
---@param m biscide.Missing
---@param lang string
function M.templates(m, lang)
  local list = vim.list_extend(templates.yours(lang), vim.deepcopy(templates.TEMPLATES[lang] or {}))
  list = vim.tbl_filter(function(t)
    return not t.recv or m.recv ~= nil
  end, list)
  require("biscide.picker").open({
    title = "Template for " .. m.name,
    items = list,
    format = function(t)
      return { text = t.title, detail = t.yours and "yours" or "biscide's", kind = "template" }
    end,
    preview = function(t)
      return { lines = (templates.expand(t, vars_of(m))), ft = lang }
    end,
    confirm = function(t)
      create(t, m)
    end,
  })
end

--- Resolves missing name `m` of the active declaration: a picker of what
--- can be done (the language server's fixes come as it answers).
---@param m biscide.Missing
function M.resolve(m)
  local n = State.active()
  if not n then
    return
  end
  local lang = templates.lang(n.path)
  local buf = Cards.buffer(n.path)
  local items = {}
  -- Declarations of the program of that name, to import.
  for _, d in ipairs(State.graph.nodes) do
    if not d.part and d.short == m.name and d.id ~= n.id and (not m.recv or d.name:find(m.recv, 1, true)) then
      items[#items + 1] = { type = "import", node = d }
    end
  end
  -- Each kind, from scratch: what it seems to be first, the rest in order.
  local kinds = vim.tbl_filter(function(t)
    return (t.kind == "method") == (m.recv ~= nil)
  end, templates.SKELETONS[lang] or {})
  for pass = 1, 2 do
    for _, t in ipairs(kinds) do
      if (t.kind == (m.hint == "type" and "struct" or m.hint)) == (pass == 1) then
        items[#items + 1] = { type = "create", template = t }
      end
    end
  end
  items[#items + 1] = { type = "templates" }
  require("biscide.picker").open({
    title = "Resolve " .. (m.recv and (m.recv .. ".") or "") .. m.name,
    -- The language server's fixes first (they know the most); the rest
    -- once they come, or without them if it is slow to answer.
    items = function(emit, done)
      local sent = false
      local function send(actions)
        if sent then
          return
        end
        sent = true
        emit(vim.tbl_map(function(a)
          return { type = "fix", action = a.action, client = a.client }
        end, actions))
        emit(items)
        done()
      end
      if #vim.lsp.get_clients({ bufnr = buf, method = "textDocument/codeAction" }) == 0 then
        return send({})
      end
      code_actions(buf, range_of(m), m.diagnostics, { "quickfix" }, send)
      vim.defer_fn(function()
        send({})
      end, 800)
    end,
    format = function(it)
      if it.type == "fix" then
        return { text = "Fix: " .. it.action.title, detail = it.client.name, kind = "fix" }
      elseif it.type == "import" then
        return { text = "Import " .. it.node.name, detail = ("%s:%d"):format(it.node.rel, it.node.srow + 1), kind = "import" }
      elseif it.type == "create" then
        local what = it.template.title .. " " .. m.name .. (m.recv and (" on " .. m.recv) or "")
        return { text = "Create " .. what, detail = "from scratch, at the end of " .. n.rel, kind = "create" }
      end
      return { text = "From a template…", detail = "biscide's, or yours", kind = "template" }
    end,
    preview = function(it)
      if it.type == "import" then
        return { path = it.node.path, lnum = it.node.srow + 1 }
      elseif it.type == "create" then
        return { lines = (templates.expand(it.template, vars_of(m))), ft = lang }
      end
    end,
    confirm = function(it)
      if it.type == "fix" then
        apply(it.action, it.client)
      elseif it.type == "import" then
        import(m, n, it.node)
      elseif it.type == "create" then
        create(it.template, m)
      else
        M.templates(m, lang)
      end
    end,
  })
end

--- Resolves the missing name of card `id` (its negative id).
function M.open(id)
  local m = M.shown[id]
  if m then
    M.resolve(m)
  end
end

--- Resolves the missing name under the cursor (else the active
--- declaration's first one).
function M.at_cursor()
  local n = State.active()
  if not n then
    return
  end
  local list = M.of(n)
  if #list == 0 then
    return require("biscide.view").notice("Nothing missing here.")
  end
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  for _, m in ipairs(list) do
    for _, d in ipairs(m.diagnostics) do
      local line = vim.api.nvim_buf_get_lines(0, d.lnum, d.lnum + 1, false)[1] or ""
      local s = line:find(m.name, d.col + 1, true)
      if d.lnum == row - 1 and s and col >= s - 1 and col < s - 1 + #m.name then
        return M.resolve(m)
      end
    end
  end
  M.resolve(list[1])
end

return M
