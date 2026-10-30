-- biscide's pickers (biscide.picker), by name: the declarations, the
-- project's files, grep (as typed, ripgrep's or git's), the word under the
-- cursor grepped, the diagnostics, the declarations gone to, the commands,
-- the keymaps, the pickers themselves, the last one again. Each is a
-- function that makes its spec; `open(name)` opens one (:BiscidePick).

local picker = require("biscide.picker")

local M = {}

local function State()
  return require("biscide.state")
end

local function abs(rel)
  return State().root .. "/" .. rel
end

local function file_kind(path)
  if path:match("%.go$") then
    return "file:go"
  elseif path:match("%.rs$") then
    return "file:rust"
  end
  return "file"
end

--- Goes to row `row` (from 0), column `col`, of file `rel`: its declaration
--- the active one, the cursor there.
function M.go_to(rel, row, col)
  local program = require("biscide.program")
  program.open(rel, row)
  local card = require("biscide.navigate").focus_active()
  local n = State().active()
  if card and n and n.rel == rel and row >= n.srow and row <= n.erow then
    pcall(vim.api.nvim_win_set_cursor, card.win, { row + 1, col or 0 })
  end
end

--- The lines a command prints, as they come, `parse`d into items: a
--- source for the picker (its stop: the command killed).
---@param cmd string[]
---@param parse fun(line: string): any?
local function command_source(cmd, parse)
  return function(emit, done)
    local rest = ""
    local function take(data)
      local items = {}
      local text = rest .. data
      local last = 1
      for line, e in text:gmatch("([^\n]*)\n()") do
        local it = parse(line)
        if it then
          items[#items + 1] = it
        end
        last = e
      end
      rest = text:sub(last)
      if #items > 0 then
        emit(items)
      end
    end
    local ok, proc = pcall(vim.system, cmd, {
      cwd = State().root,
      text = true,
      stdout = function(_, data)
        if data then
          take(data)
        end
      end,
    }, function()
      if rest ~= "" then
        take("\n")
      end
      done()
    end)
    if not ok then
      done()
      return
    end
    return function()
      pcall(proc.kill, proc, "sigterm")
    end
  end
end

---@type table<string, { desc: string, spec: fun(arg?: string): biscide.PickerSpec? }>
local P = {}

P.declarations = {
  desc = "the program's declarations",
  spec = function(query)
    local graph = State().graph
    if not graph then
      return nil
    end
    local items = vim.tbl_filter(function(n)
      return not n.part
    end, graph.nodes)
    return {
      title = "Declarations",
      items = items,
      query = query,
      format = function(n)
        return { text = n.name, detail = ("%s:%d"):format(n.rel, n.srow + 1), kind = n.kind }
      end,
      preview = function(n)
        return { path = n.path, lnum = (n.nrow or n.srow) + 1 }
      end,
      confirm = function(n)
        require("biscide.navigate").go(n.id, "jump")
      end,
    }
  end,
}

P.files = {
  desc = "the project's files",
  spec = function(query)
    local project = State().project
    if not project then
      return nil
    end
    return {
      title = "Files",
      items = project.files,
      query = query,
      format = function(rel)
        return { text = rel, kind = file_kind(rel) }
      end,
      preview = function(rel)
        return { path = abs(rel) }
      end,
      confirm = function(rel)
        require("biscide.program").open(rel)
      end,
    }
  end,
}

--- A grep of the project's Go and Rust files: ripgrep's, else git's.
---@param query string
---@param word? boolean the query a whole word, as written
local function grep_cmd(query, word)
  if vim.fn.executable("rg") == 1 then
    local cmd = { "rg", "--vimgrep", "--smart-case", "--max-columns", "400", "--type", "go", "--type", "rust" }
    if word then
      vim.list_extend(cmd, { "--word-regexp", "--fixed-strings" })
    end
    vim.list_extend(cmd, { "--", query })
    return cmd
  end
  local cmd = { "git", "grep", "-n", "--column", "-I", "-i" }
  if word then
    vim.list_extend(cmd, { "-w", "-F" })
  end
  vim.list_extend(cmd, { "-e", query, "--", "*.go", "*.rs" })
  return cmd
end

---@param word? boolean
local function grep_spec(query, word)
  return {
    title = word and ("Grep: " .. query) or "Grep",
    query = query,
    empty = "Type to grep the Go and Rust files.",
    live = function(q, emit, done)
      local src = command_source(grep_cmd(q, word), function(line)
        local rel, lnum, col, text = line:match("^(.-):(%d+):(%d+):(.*)$")
        if rel then
          return { rel = rel, lnum = tonumber(lnum), col = tonumber(col) - 1, text = text, len = #q }
        end
      end)
      return src(emit, done)
    end,
    format = function(it)
      return { text = vim.trim(it.text), detail = ("%s:%d"):format(it.rel, it.lnum), kind = "grep" }
    end,
    preview = function(it)
      return { path = abs(it.rel), lnum = it.lnum, col = it.col, end_col = it.col + it.len }
    end,
    confirm = function(it)
      M.go_to(it.rel, it.lnum - 1, it.col)
    end,
  }
end

P.grep = {
  desc = "grep the project, as typed",
  spec = function(query)
    return grep_spec(query or "")
  end,
}

P.grep_word = {
  desc = "grep the word under the cursor",
  spec = function()
    local word = vim.fn.expand("<cword>")
    if word == "" then
      return nil
    end
    return grep_spec(word, true)
  end,
}

local SEVERITY = { "error", "warn", "info", "hint" }

P.diagnostics = {
  desc = "the diagnostics of the open files",
  spec = function(query)
    local items = {}
    for _, d in ipairs(vim.diagnostic.get(nil)) do
      local name = vim.api.nvim_buf_get_name(d.bufnr)
      local rel = State().root and vim.fs.relpath(State().root, name) or name
      items[#items + 1] = vim.tbl_extend("force", d, { rel = rel, path = name })
    end
    table.sort(items, function(a, b)
      if a.severity ~= b.severity then
        return a.severity < b.severity
      end
      if a.rel ~= b.rel then
        return a.rel < b.rel
      end
      return a.lnum < b.lnum
    end)
    return {
      title = "Diagnostics",
      items = items,
      query = query,
      empty = "No diagnostics.",
      format = function(d)
        local msg = d.message:match("^[^\n]*")
        local src = d.source and (d.source .. ": ") or ""
        return { text = src .. msg, detail = ("%s:%d"):format(d.rel or "", d.lnum + 1), kind = SEVERITY[d.severity] }
      end,
      preview = function(d)
        local end_col = d.end_lnum == d.lnum and d.end_col or nil
        return { path = d.path, lnum = d.lnum + 1, col = d.col, end_col = end_col }
      end,
      confirm = function(d)
        if d.rel then
          M.go_to(d.rel, d.lnum, d.col)
        end
      end,
    }
  end,
}

P.history = {
  desc = "the declarations gone to",
  spec = function(query)
    local history = State().history
    local items = {}
    for k = #history.list, 1, -1 do
      items[#items + 1] = { k = k, entry = history.list[k] }
    end
    return {
      title = "Declarations gone to",
      items = items,
      query = query,
      empty = "Nowhere yet.",
      format = function(it)
        local e = it.entry
        return { text = e.name, detail = ("%s:%d"):format(e.rel, e.srow + 1), kind = "history" }
      end,
      preview = function(it)
        return { path = abs(it.entry.rel), lnum = it.entry.srow + 1 }
      end,
      confirm = function(it)
        require("biscide.navigate").history_to(it.k)
      end,
    }
  end,
}

P.commands = {
  desc = "the Ex commands defined",
  spec = function(query)
    local items = {}
    for name, c in pairs(vim.api.nvim_get_commands({})) do
      items[#items + 1] = { name = name, desc = c.definition or "", nargs = c.nargs }
    end
    table.sort(items, function(a, b)
      return a.name < b.name
    end)
    return {
      title = "Commands",
      items = items,
      query = query,
      format = function(c)
        return { text = c.name, detail = c.desc, kind = "command" }
      end,
      confirm = function(c)
        -- On the command line, to be run (or given its arguments first).
        local keys = ":" .. c.name .. (c.nargs == "0" and "" or " ")
        vim.api.nvim_feedkeys(keys, "n", false)
      end,
    }
  end,
}

P.keymaps = {
  desc = "the keymaps of Normal mode",
  spec = function(query)
    local items, seen = {}, {}
    local function add(list, where)
      for _, m in ipairs(list) do
        if not seen[m.lhs] and not m.lhs:match("^<Plug>") then
          seen[m.lhs] = true
          items[#items + 1] = { lhs = m.lhs, desc = m.desc or m.rhs or "", where = where }
        end
      end
    end
    -- In the order they are looked up in.
    add(vim.api.nvim_gui_get_keymap("n"), "gui")
    add(vim.api.nvim_buf_get_keymap(0, "n"), "buffer")
    add(vim.api.nvim_get_keymap("n"), "global")
    return {
      title = "Keymaps",
      items = items,
      query = query,
      format = function(m)
        local lhs = vim.fn.keytrans(vim.keycode(m.lhs)):gsub(vim.pesc(vim.fn.keytrans(vim.g.mapleader or "\\")), "<leader>", 1)
        return { text = lhs, detail = m.desc .. "  (" .. m.where .. ")", kind = "keymap" }
      end,
      confirm = function(m)
        vim.api.nvim_feedkeys(vim.keycode(m.lhs), "m", false)
      end,
    }
  end,
}

P.pickers = {
  desc = "the pickers",
  spec = function(query)
    local items = {}
    for name, p in pairs(P) do
      items[#items + 1] = { name = name, desc = p.desc }
    end
    table.sort(items, function(a, b)
      return a.name < b.name
    end)
    return {
      title = "Pickers",
      items = items,
      query = query,
      format = function(it)
        return { text = it.name, detail = it.desc, kind = "picker" }
      end,
      confirm = function(it)
        M.open(it.name)
      end,
    }
  end,
}

P.resume = {
  desc = "the last picker again",
  spec = function()
    picker.resume()
  end,
}

--- The pickers' names.
function M.names()
  local names = vim.tbl_keys(P)
  table.sort(names)
  return names
end

--- Opens picker `name`, its query `query`.
---@param name string
---@param query? string
function M.open(name, query)
  local p = P[name]
  if not p then
    return require("biscide.view").notice("No picker " .. name .. ".")
  end
  local spec = p.spec(query)
  if spec then
    picker.open(spec)
  end
end

return M
