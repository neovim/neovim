-- The whole program as a graph: every declaration of the project's Go and
-- Rust files a node, an edge wherever one uses another. Names are resolved
-- within scopes (a Go package and what it imports; a Rust crate and what
-- it `use`s); a name matching more than AMBIGUITY_MAX declarations is left
-- out rather than guessed. Tests, generated files and vendored code are
-- left out. Layers (biscide.toml) mark the uses pointing outward.
--
-- A node: { id, name, kind, rel, path, srow, erow, nrow, ncol, layer,
-- ident }: a declaration, or a part of a file that is none (its package
-- clause, its imports, a comment, code left: `part` set, no edges).
-- `srow..erow` are the lines of its card (a declaration's from its doc
-- comment); `ident` names it across edits (`<kind>:<name>:<n>`, the n-th of
-- that kind and name in its file).
-- An edge: { from, to, kinds (a set: call, parameter, field, type_use,
-- reference, receiver), violation (bool) }.

local outline = require("biscide.outline")

local M = {}

M.AMBIGUITY_MAX = 3
M.KINDS = { "call", "parameter", "field", "type_use", "reference", "receiver" }

local SKIPPED = { target = true, node_modules = true, vendor = true }
local WALK_MAX = 100000
local HEADER_LINES = 10

local function read(path)
  local f = io.open(path, "rb")
  if not f then
    return nil
  end
  local t = f:read("*a")
  f:close()
  return t
end
M.read = read

--- The project's files, relative to `root`: git's (tracked and untracked,
--- ignored ones left out) in a work tree, else (or when git has none: a
--- folder it ignores) a walk of the folder.
function M.files(root)
  local r = vim.system({ "git", "-C", root, "ls-files", "-co", "--exclude-standard", "-z" }, { text = true }):wait()
  local out = {}
  if r.code == 0 then
    for p in r.stdout:gmatch("([^%z]+)") do
      if vim.uv.fs_stat(root .. "/" .. p) then
        out[#out + 1] = p
      end
    end
  end
  -- Not a git work tree, or one that ignores this folder: walked.
  if #out == 0 then
    for name, kind in vim.fs.dir(root, {
      depth = math.huge,
      skip = function(dir)
        local base = vim.fs.basename(dir)
        return base:sub(1, 1) ~= "." and not SKIPPED[base]
      end,
    }) do
      if kind == "file" and not vim.fs.basename(name):match("^%.") then
        out[#out + 1] = name
      end
      if #out >= WALK_MAX then
        break
      end
    end
  end
  table.sort(out)
  return out
end

--- The modules among the files: a go.mod's directory, a Cargo.toml's with
--- none above it.
local function modules(files)
  local found = {}
  for _, f in ipairs(files) do
    local base = vim.fs.basename(f)
    if base == "go.mod" or base == "Cargo.toml" then
      local dir = vim.fs.dirname(f)
      found[#found + 1] = { root = dir == "." and "" or dir, lang = base == "go.mod" and "go" or "rust" }
    end
  end
  local cargo = {}
  for _, m in ipairs(found) do
    if m.lang == "rust" then
      cargo[#cargo + 1] = m.root
    end
  end
  return vim.tbl_filter(function(m)
    if m.lang ~= "rust" then
      return true
    end
    for _, r in ipairs(cargo) do
      if r ~= m.root and (r == "" or vim.startswith(m.root, r .. "/")) then
        return false
      end
    end
    return true
  end, found)
end

local function within(path, dir)
  return dir == "" or path == dir or vim.startswith(path, dir .. "/")
end

--- `rel` relative to its module's root (the deepest holding it).
local function in_module(mods, rel)
  local best
  for _, m in ipairs(mods) do
    if within(rel, m.root) and (not best or #m.root > #best.root) then
      best = m
    end
  end
  if not best or best.root == "" then
    return rel
  end
  return rel:sub(#best.root + 2)
end

-- ---- Layers ----

local DEFAULT_LAYERS = {
  { name = "domain", paths = { "internal/domain/**", "crates/domain/**", "domain/**" } },
  { name = "app", paths = { "internal/app/**", "crates/app/**", "app/**" } },
  { name = "adapters", paths = { "internal/adapters/**", "crates/adapters/**", "adapters/**" } },
  { name = "root", paths = { "cmd/**", "main.go", "src/**" } },
}

--- biscide.toml's `[[layer]]` tables (`name`, `paths`), the little TOML
--- they need.
local function parse_layers(toml)
  local layers, cur = {}, nil
  local i, s = 1, toml
  local function skip()
    while i <= #s do
      local c = s:sub(i, i)
      if c:match("%s") then
        i = i + 1
      elseif c == "#" then
        i = (s:find("\n", i, true) or #s) + 1
      else
        break
      end
    end
  end
  local function str()
    local q = s:sub(i, i)
    if q ~= '"' and q ~= "'" then
      return nil
    end
    local j = s:find(q, i + 1, true)
    if not j then
      return nil
    end
    local v = s:sub(i + 1, j - 1)
    i = j + 1
    return v
  end
  while true do
    skip()
    if i > #s then
      break
    end
    if s:sub(i, i) == "[" then
      local e = s:find("\n", i, true) or #s + 1
      local head = vim.trim(s:sub(i, e - 1))
      cur = nil
      if head == "[[layer]]" then
        cur = { paths = {} }
        layers[#layers + 1] = cur
      end
      i = e
    else
      local eq = s:find("=", i, true)
      if not eq then
        break
      end
      local key = vim.trim(s:sub(i, eq - 1))
      i = eq + 1
      skip()
      if s:sub(i, i) == "[" then
        i = i + 1
        local values = {}
        while true do
          skip()
          local c = s:sub(i, i)
          if c == "]" or c == "" then
            i = i + 1
            break
          elseif c == "," then
            i = i + 1
          else
            local v = str()
            if not v then
              error("biscide.toml: a list of strings for " .. key)
            end
            values[#values + 1] = v
          end
        end
        if cur and key == "paths" then
          cur.paths = values
        end
      else
        local v = str()
        if cur and key == "name" then
          cur.name = v
        end
        if not v then
          i = (s:find("\n", i, true) or #s) + 1
        end
      end
    end
  end
  return #layers > 0 and layers or nil
end

--- The layers, inner to outer, each with its globs' matchers.
function M.layers(root)
  local spec = DEFAULT_LAYERS
  local toml = read(root .. "/biscide.toml")
  if toml then
    local ok, parsed = pcall(parse_layers, toml)
    if ok and parsed then
      spec = parsed
    elseif not ok then
      vim.notify("biscide: " .. tostring(parsed) .. "; the default layers", vim.log.levels.WARN)
    end
  end
  local layers = {}
  for rank, l in ipairs(spec) do
    local m = {}
    for _, g in ipairs(l.paths or {}) do
      local ok, pat = pcall(vim.glob.to_lpeg, g)
      if ok then
        m[#m + 1] = pat
      end
    end
    layers[#layers + 1] = { name = l.name, rank = rank, matchers = m }
  end
  return layers
end

local function classify(layers, path)
  for _, l in ipairs(layers) do
    for _, m in ipairs(l.matchers) do
      if m:match(path) then
        return l
      end
    end
  end
end

-- ---- Scopes ----

local function package_name(manifest)
  local in_package = false
  for line in manifest:gmatch("[^\n]+") do
    line = vim.trim(line)
    if line:sub(1, 1) == "[" then
      in_package = line == "[package]"
    elseif in_package then
      local v = line:match('^name%s*=%s*"([^"]+)"')
      if v then
        return v
      end
    end
  end
end

--- Each Go module's path and directory; each crate's name (as code spells
--- it) and directory.
local function scopes(root, files, mods)
  local go, crates = {}, {}
  for _, m in ipairs(mods) do
    if m.lang == "go" then
      local text = read(root .. "/" .. (m.root == "" and "" or m.root .. "/") .. "go.mod")
      local path = text and text:match("module%s+([^%s]+)")
      if path then
        go[#go + 1] = { path, m.root }
      end
    end
  end
  for _, f in ipairs(files) do
    if vim.fs.basename(f) == "Cargo.toml" then
      local text = read(root .. "/" .. f)
      local name = text and package_name(text)
      if name then
        local dir = vim.fs.dirname(f)
        crates[#crates + 1] = { (name:gsub("-", "_")), dir == "." and "" or dir }
      end
    end
  end
  return { go = go, crates = crates }
end

local function go_scope(sc, import)
  local best
  for _, m in ipairs(sc.go) do
    if (import == m[1] or vim.startswith(import, m[1] .. "/")) and (not best or #m[1] > #best[1]) then
      best = m
    end
  end
  if not best then
    return nil
  end
  local rest = import:sub(#best[1] + 1):gsub("^/+", "")
  if rest == "" then
    return best[2]
  elseif best[2] == "" then
    return rest
  end
  return best[2] .. "/" .. rest
end

local function crate_scope(sc, name)
  for _, c in ipairs(sc.crates) do
    if c[1] == name then
      return c[2]
    end
  end
end

local function scope_of(rel, lang, sc)
  local dir = vim.fs.dirname(rel)
  dir = dir == "." and "" or dir
  if lang ~= "rust" then
    return dir
  end
  local best
  for _, c in ipairs(sc.crates) do
    if within(dir, c[2]) and (not best or #c[2] > #best) then
      best = c[2]
    end
  end
  return best or dir
end

local function is_source(rel)
  local name = vim.fs.basename(rel)
  local lang = name:match("%.go$") and "go" or name:match("%.rs$") and "rust" or nil
  if not lang then
    return nil
  end
  if lang == "go" and (name:match("_test%.go$") or name:match("%.pb%.go$") or name:match("_gen%.go$")
      or name:match("%.pb%.gw%.go$")) then
    return nil
  end
  if lang == "rust" then
    for part in rel:gmatch("[^/]+") do
      if part == "tests" or part == "benches" then
        return nil
      end
    end
  end
  return lang
end

local function is_generated(text)
  local n = 0
  for line in text:gmatch("[^\n]*") do
    n = n + 1
    if n > HEADER_LINES then
      break
    end
    if line:find("Code generated", 1, true) and line:find("DO NOT EDIT", 1, true) then
      return true
    end
  end
  return false
end

-- ---- The graph ----

local function kind_of(role, target)
  local is_type = target.kind == "struct" or target.kind == "interface" or target.kind == "enum"
    or target.kind == "type"
  if role == "signature" then
    return "parameter"
  elseif role == "field" then
    return "field"
  elseif is_type then
    return "type_use"
  elseif role == "call" then
    return "call"
  end
  return "reference"
end

--- Outlines one file: what `build` needs of it. `text` read when not given
--- (a buffer's lines, unsaved, may be given).
function M.source(project, rel, text)
  local lang = is_source(rel)
  if not lang then
    return nil
  end
  text = text or read(project.root .. "/" .. rel)
  if not text or is_generated(text) then
    return nil
  end
  local layer = classify(project.layers, in_module(project.modules, rel))
  return {
    rel = rel,
    path = project.root .. "/" .. rel,
    lang = lang,
    scope = scope_of(rel, lang, project.scopes),
    layer = layer and layer.name,
    rank = layer and layer.rank,
    outline = outline.outline(text, lang),
  }
end

--- A file that is neither Go nor Rust (a configuration, a document) as a
--- source of one part, the whole file: opened, it is a card of its own.
--- Not text (a NUL in it): none.
---@param text? string its text (else the file's)
function M.plain_source(project, rel, text)
  text = text or read(project.root .. "/" .. rel)
  if not text or text:find("\0", 1, true) then
    return nil
  end
  local lines = vim.split(text, "\n", { plain = true })
  local count = (lines[#lines] == "" and #lines > 1) and #lines - 1 or #lines
  local dir = vim.fs.dirname(rel)
  return {
    rel = rel,
    path = project.root .. "/" .. rel,
    lang = "text",
    scope = dir == "." and "" or dir,
    outline = {
      decls = {},
      imports = {},
      import_rows = {},
      parts = { { kind = "file", name = vim.fs.basename(rel), srow = 0, erow = math.max(0, count - 1) } },
    },
  }
end

--- The project at `root`: its files, modules, scopes, layers, sources.
function M.project(root)
  local files = M.files(root)
  local mods = modules(files)
  local project = { root = root, files = files, modules = mods, layers = M.layers(root) }
  project.scopes = scopes(root, files, mods)
  project.sources = {}
  for _, rel in ipairs(files) do
    local s = M.source(project, rel)
    if s then
      project.sources[#project.sources + 1] = s
    end
  end
  return project
end

--- The graph of the project's sources.
function M.build(project)
  local nodes, edges = {}, {}
  local top, methods = {}, {}
  local origin = {}
  local function index(t, scope, name)
    local s = t[scope]
    return s and s[name] or {}
  end
  for _, f in ipairs(project.sources) do
    for _, d in ipairs(f.outline.decls) do
      local id = #nodes + 1
      nodes[id] = {
        id = id,
        name = d.receiver and (d.receiver .. "." .. d.name) or d.name,
        short = d.name,
        kind = d.kind,
        rel = f.rel,
        path = f.path,
        srow = d.srow,
        erow = d.erow,
        nrow = d.nrow,
        ncol = d.ncol,
        layer = f.layer,
        rank = f.rank,
      }
      origin[id] = { f, d }
      local t = d.receiver and methods or top
      t[f.scope] = t[f.scope] or {}
      t[f.scope][d.name] = t[f.scope][d.name] or {}
      table.insert(t[f.scope][d.name], id)
    end
  end
  local sc = project.scopes
  local function used_from(f, name)
    for _, i in ipairs(f.outline.imports) do
      if i.alias == name then
        return crate_scope(sc, vim.split(i.path, "::", { plain = true })[1])
      end
    end
  end
  local function resolve(f, r)
    if f.lang == "go" then
      if not r.q then
        return index(top, f.scope, r.name)
      end
      for _, i in ipairs(f.outline.imports) do
        if i.alias == r.q then
          local s = go_scope(sc, i.path)
          return s and index(top, s, r.name) or {}
        end
      end
      return index(methods, f.scope, r.name)
    end
    if not r.q then
      local here = index(top, f.scope, r.name)
      if #here > 0 then
        return here
      end
      local s = used_from(f, r.name)
      return s and index(top, s, r.name) or {}
    end
    local s = crate_scope(sc, r.q) or used_from(f, r.q)
    if s then
      return index(top, s, r.name)
    end
    local m = index(methods, f.scope, r.name)
    if #m > 0 then
      return m
    end
    return index(top, f.scope, r.name)
  end
  for from = 1, #nodes do
    local f, d = origin[from][1], origin[from][2]
    local targets = {}
    local function add(to, kind)
      if to ~= from then
        targets[to] = targets[to] or {}
        targets[to][kind] = true
      end
    end
    for _, r in ipairs(d.refs) do
      local found = resolve(f, r)
      if #found <= M.AMBIGUITY_MAX then
        for _, t in ipairs(found) do
          add(t, kind_of(r.role, nodes[t]))
        end
      end
    end
    if d.receiver then
      local found = index(top, f.scope, d.receiver)
      if #found <= M.AMBIGUITY_MAX then
        for _, t in ipairs(found) do
          add(t, "receiver")
        end
      end
    end
    local tos = vim.tbl_keys(targets)
    table.sort(tos)
    for _, to in ipairs(tos) do
      local a, b = nodes[from].rank, nodes[to].rank
      edges[#edges + 1] = { from = from, to = to, kinds = targets[to], violation = (a and b and a < b) or false }
    end
  end
  -- The parts of the files that are no declaration: nodes without edges.
  for _, f in ipairs(project.sources) do
    for _, p in ipairs(f.outline.parts or {}) do
      local id = #nodes + 1
      nodes[id] = {
        id = id,
        name = p.name,
        short = p.name,
        kind = p.kind,
        rel = f.rel,
        path = f.path,
        srow = p.srow,
        erow = p.erow,
        nrow = p.srow,
        ncol = 0,
        layer = f.layer,
        rank = f.rank,
        part = true,
      }
    end
  end
  -- Each node's identity in its file, the same across edits.
  local seen = {}
  for _, n in ipairs(nodes) do
    local base = n.rel .. "\0" .. n.kind .. ":" .. n.name
    seen[base] = (seen[base] or 0) + 1
    n.ident = ("%s:%s:%d"):format(n.kind, n.name, seen[base])
  end
  -- What each node uses and what uses it, for the lanes.
  for _, n in ipairs(nodes) do
    n.out, n.inc = {}, {}
  end
  for _, e in ipairs(edges) do
    table.insert(nodes[e.from].out, e)
    table.insert(nodes[e.to].inc, e)
  end
  return { nodes = nodes, edges = edges }
end

-- ---- Finding declarations ----

--- The innermost declaration of file `rel` holding line `row` (from 0).
---@return integer?
function M.declaration_at(g, rel, row)
  local best
  for _, n in ipairs(g.nodes) do
    if n.rel == rel and n.srow <= row and row <= n.erow then
      if not best or (n.erow - n.srow) < (best.erow - best.srow) then
        best = n
      end
    end
  end
  return best and best.id
end

--- The first declaration of `rel` at or after `row`, else its last.
---@return integer?
function M.nearest_in_file(g, rel, row)
  local last, after
  for _, n in ipairs(g.nodes) do
    if n.rel == rel then
      if n.srow >= row and (not after or n.srow < after.srow) then
        after = n
      end
      if not last or n.srow > last.srow then
        last = n
      end
    end
  end
  local n = after or last
  return n and n.id
end

--- The declaration a place in a file is in, else the nearest there.
function M.at(g, rel, row)
  return M.declaration_at(g, rel, row) or M.nearest_in_file(g, rel, row)
end

--- The declaration a history entry names: by its place, else by its name
--- in its file (it moved).
---@param entry biscide.HistoryEntry
---@return integer?
function M.find(g, entry)
  if entry.ident then
    for _, n in ipairs(g.nodes) do
      if n.rel == entry.rel and n.ident == entry.ident then
        return n.id
      end
    end
  end
  for _, n in ipairs(g.nodes) do
    if n.rel == entry.rel and n.srow == entry.srow then
      return n.id
    end
  end
  for _, n in ipairs(g.nodes) do
    if n.rel == entry.rel and n.name == entry.name then
      return n.id
    end
  end
end

return M
