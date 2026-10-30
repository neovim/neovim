-- The project's files as a tree: directories first, by name, case aside;
-- the root with its path. The GUI draws it (`vim._gui_send("tree", …)`:
-- its rows, which is selected, which file is the active declaration's) in
-- its panel; this keeps the model. The keyboard is a buffer's
-- (`biscide://tree`, filetype biscide_tree, in a window the GUI does not
-- show): a row a line, the cursor the selected row, so Nvim's own keys move
-- (j k gg G / and counts), and its maps: <CR> o open a file or a
-- directory, l opens a directory, h closes one (or goes to its parent), q
-- closes the tree, <Esc> and <C-w>l give the keyboard back to the active
-- card. The mouse comes from the GUI: `click`, `activate`.

local M = {}

local T = {
  root = nil,
  name = "",
  children = {}, -- directory → its entries ({ path, name, dir })
  expanded = { [""] = true },
  rows = {}, -- the rows shown: { path, name, depth, dir, expanded }
  want = nil, -- the path the cursor goes to when the tree shows
  active = nil, -- the active declaration's file
  buf = nil,
  win = nil,
  open = false,
}
M.state = T

local function join(dir, name)
  return dir == "" and name or (dir .. "/" .. name)
end

local function parent(path)
  return path:match("^(.*)/[^/]*$") or ""
end

local function build(paths)
  local children, dirs = { [""] = {} }, {}
  for _, path in ipairs(paths) do
    local dir = ""
    local parts = vim.split(path, "/", { plain = true, trimempty = true })
    for i, part in ipairs(parts) do
      local child = join(dir, part)
      local is_dir = i < #parts
      if not is_dir or not dirs[child] then
        if is_dir then
          dirs[child] = true
        end
        children[dir] = children[dir] or {}
        table.insert(children[dir], { path = child, name = part, dir = is_dir })
      end
      if is_dir then
        children[child] = children[child] or {}
      end
      dir = child
    end
  end
  for _, entries in pairs(children) do
    table.sort(entries, function(a, b)
      if a.dir ~= b.dir then
        return a.dir
      end
      return a.name:lower() < b.name:lower()
    end)
  end
  return children
end

local function rows()
  local out = {}
  if not T.root then
    return out
  end
  out[1] = { path = "", name = T.name, depth = 0, dir = true, expanded = T.expanded[""] }
  local function push(dir, depth)
    for _, e in ipairs(T.children[dir] or {}) do
      local open = e.dir and T.expanded[e.path] or false
      out[#out + 1] = { path = e.path, name = e.name, depth = depth, dir = e.dir, expanded = open }
      if open then
        push(e.path, depth + 1)
      end
    end
  end
  if T.expanded[""] then
    push("", 1)
  end
  return out
end

local KINDS = {
  go = "go",
  rs = "rust",
  lua = "lua",
  md = "doc",
  txt = "doc",
  toml = "config",
  mod = "config",
  sum = "config",
  json = "config",
  yaml = "config",
  yml = "config",
}

--- A file's kind, for its icon's colour.
local function kind_of(r)
  if r.dir then
    return "dir"
  end
  return KINDS[r.name:match("%.([%w]+)$") or ""] or "file"
end

local function window()
  return T.win and vim.api.nvim_win_is_valid(T.win) and T.win or nil
end

--- The row under the buffer's cursor (from 1).
local function cursor_row()
  local win = window()
  return win and vim.api.nvim_win_get_cursor(win)[1] or 1
end

local function selected()
  return T.rows[cursor_row()]
end

local function index_of(path)
  for k, r in ipairs(T.rows) do
    if r.path == path then
      return k
    end
  end
end

--- Tells the GUI the tree: whether it shows, has the keyboard, its rows,
--- the selected one.
function M.notify()
  local out = {}
  for k, r in ipairs(T.rows) do
    out[k] = { name = r.name, path = r.path, depth = r.depth, dir = r.dir, expanded = r.expanded, kind = kind_of(r) }
  end
  require("biscide.view").send("tree", {
    open = T.open,
    focused = window() ~= nil and vim.api.nvim_get_current_win() == T.win,
    root = T.root or vim.NIL,
    active = T.active or vim.NIL,
    rows = out,
    selected = cursor_row(),
  })
end

--- The rows worked out again and put in the buffer, the cursor kept on
--- `keep` (a path).
local function render(keep)
  if not (T.buf and vim.api.nvim_buf_is_valid(T.buf)) then
    return
  end
  keep = keep or (selected() or {}).path
  T.rows = rows()
  -- A row a line: its name, indented (for / and the like).
  local lines = {}
  for k, r in ipairs(T.rows) do
    lines[k] = string.rep("  ", r.depth) .. r.name
  end
  vim.bo[T.buf].modifiable = true
  vim.api.nvim_buf_set_lines(T.buf, 0, -1, false, lines)
  vim.bo[T.buf].modifiable = false
  local at = keep and index_of(keep)
  if at and window() then
    vim.api.nvim_win_set_cursor(T.win, { at, 0 })
  end
  M.notify()
end

local function toggle_dir(path)
  T.expanded[path] = not T.expanded[path] or nil
  if path == "" then
    T.expanded[""] = T.expanded[""] or false
  end
  render(path)
end

--- Opens row `r`: a file goes to the middle (the keyboard with it), a
--- directory opens or closes.
local function open_row(r)
  if not r then
    return
  end
  if r.dir then
    return toggle_dir(r.path)
  end
  M.leave()
  require("biscide.program").open(r.path)
end

function M.open_selected()
  open_row(selected())
end

function M.expand()
  local r = selected()
  if not r or not r.dir then
    return
  end
  if not r.expanded then
    toggle_dir(r.path)
  else
    vim.cmd("normal! j")
  end
end

function M.collapse()
  local r = selected()
  if not r then
    return
  end
  if r.dir and r.expanded then
    toggle_dir(r.path)
  elseif r.path ~= "" then
    local at = index_of(parent(r.path))
    if at then
      vim.api.nvim_win_set_cursor(T.win, { at, 0 })
    end
  end
end

--- Row `k` (from 1) clicked: selected, the keyboard to the tree; a
--- directory opens or closes.
function M.click(k)
  local r = T.rows[k]
  if not (r and window()) then
    return
  end
  vim.api.nvim_set_current_win(T.win)
  vim.api.nvim_win_set_cursor(T.win, { k, 0 })
  if r.dir then
    return toggle_dir(r.path)
  end
  M.notify()
end

--- Row `k` (from 1) double-clicked: opened.
function M.activate(k)
  open_row(T.rows[k])
end

--- The keyboard back to the active card (the tree stays shown).
function M.leave()
  require("biscide.navigate").focus_active()
  M.notify()
end

local function make_buf()
  if T.buf and vim.api.nvim_buf_is_valid(T.buf) then
    return T.buf
  end
  T.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(T.buf, "biscide://tree")
  vim.bo[T.buf].filetype = "biscide_tree"
  vim.bo[T.buf].bufhidden = "hide"
  vim.bo[T.buf].modifiable = false
  local function map(lhs, fn)
    vim.keymap.set("n", lhs, fn, { buffer = T.buf, nowait = true, desc = "biscide tree" })
  end
  map("<CR>", M.open_selected)
  map("o", M.open_selected)
  map("l", M.expand)
  map("<Right>", M.expand)
  map("h", M.collapse)
  map("<Left>", M.collapse)
  map("q", M.close)
  map("<Esc>", M.leave)
  map("<C-w>l", M.leave)
  vim.api.nvim_create_autocmd("CursorMoved", { buffer = T.buf, callback = M.notify })
  return T.buf
end

--- Shows the tree; `focus`: the keyboard to it.
function M.open(focus)
  make_buf()
  if not window() then
    T.win = vim.api.nvim_open_win(T.buf, false, {
      relative = "editor",
      row = 0,
      col = 0,
      width = 40,
      height = math.max(5, vim.o.lines - 2),
      style = "minimal",
      zindex = 20,
    })
    vim.w[T.win].biscide_ui = true
    vim.wo[T.win].wrap = false
    render(T.want)
  end
  T.open = true
  if focus then
    vim.api.nvim_set_current_win(T.win)
  end
  M.notify()
end

function M.close()
  if window() then
    if vim.api.nvim_get_current_win() == T.win then
      require("biscide.navigate").focus_active()
    end
    pcall(vim.api.nvim_win_close, T.win, true)
  end
  T.win = nil
  T.open = false
  M.notify()
end

--- Shows the tree with the keyboard; hides it when it has the keyboard.
function M.toggle()
  if T.open and window() and vim.api.nvim_get_current_win() == T.win then
    return M.close()
  end
  M.open(true)
end

--- The project's files (the program read again).
function M.set_files(root, paths)
  if T.root ~= root then
    T.expanded = { [""] = true }
  end
  T.root = root
  T.name = vim.fs.basename(root)
  T.children = build(paths)
  make_buf()
  render()
end

--- Expands the directories down to `rel` and puts the cursor on it.
function M.reveal(rel)
  if not rel then
    return
  end
  local dir = ""
  local parts = vim.split(rel, "/", { plain = true })
  for i = 1, #parts - 1 do
    dir = join(dir, parts[i])
    T.expanded[dir] = true
  end
  T.want = rel
  render(rel)
end

vim.api.nvim_create_autocmd({ "WinEnter", "WinLeave" }, {
  group = vim.api.nvim_create_augroup("biscide_tree", { clear = true }),
  callback = function()
    if T.open then
      vim.schedule(M.notify)
    end
  end,
})

-- The active declaration's file is the one selected.
vim.api.nvim_create_autocmd("User", {
  group = vim.api.nvim_create_augroup("biscide_tree_reveal", { clear = true }),
  pattern = "BiscideActive",
  callback = function(a)
    if T.root and a.data and a.data.path then
      T.active = a.data.path
      M.reveal(a.data.path)
    end
  end,
})

return M
