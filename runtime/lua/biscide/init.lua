-- biscide: Nvim as a graph IDE for Go and Rust. The program of the project
-- (its declarations, biscide.graph) is walked declaration by declaration: one
-- in the middle with its file's declarations stacked around it, what uses
-- it on the left, what it uses on the right, the one the reader came from
-- at the far left. Each card is a floating window on the real file's buffer
-- kept to its part (biscide.narrow): every line of a file is in one card (a
-- declaration with its doc comment, the package clause, the imports, a
-- comment, code left), the language server sees the whole file, `:w` is an
-- ordinary write.
--
-- Nvim runs it all: keys, maps, counts, commands, the configuration. Nvim's
-- built-in GUI (`nvim --gui`) paints the cards' windows and the curves
-- between them; it hears the state from biscide.view and calls back here.
--
-- The modules: biscide.state (the state, in one place), biscide.cards (the
-- cards: structs in a registry), biscide.narrow (a window kept to its part,
-- the range its own state), biscide.lanes (the lanes, worked out), biscide.view
-- (the presenter), biscide.navigate (moving), biscide.program (reading the
-- program), biscide.keymaps, biscide.commands, biscide.tree (the files),
-- biscide.picker and biscide.pickers (finding), biscide.ui (vim.ui and
-- vim.notify, shown by the GUI), biscide.missing and biscide.templates (names
-- that are nowhere: imported, or created from scratch or a template).
--
-- Commands: :BiscideGo :BiscideBack :BiscideLane {dir} :BiscideHistory
-- {back|forward} :BiscideTree [toggle|open|close|reveal] :BiscidePick {name}
-- :BiscideFind :BiscideMessages [toggle|open|close|clear] :BiscideNew :BiscideResolve
-- :BiscideCentre :BiscideReload :BiscideCardCols {n}. Keys: the GUI's keymaps
-- (biscide.keymaps). Events: `User BiscideActive` (data: name, path, line),
-- `User BiscideReady`.

local State = require("biscide.state")
local Cards = require("biscide.cards")
local navigate = require("biscide.navigate")
local program = require("biscide.program")
local view = require("biscide.view")

local M = {}

M.state = State

-- The calls of the GUI and of the configuration.
M.go = navigate.go
M.back = navigate.back
M.history = navigate.history
M.history_to = navigate.history_to
M.lane = navigate.lane
M.go_cursor = navigate.go_cursor
M.drop_cursor = navigate.drop_cursor
M.centre = navigate.centre
M.new = navigate.new
M.mark = navigate.mark
M.activate = navigate.activate
M.focus_active = navigate.focus_active
M.open = program.open
M.reload = program.reload
M.render = view.render

--- The card of declaration `id` in `lane`, if shown.
---@param id integer
---@param lane biscide.Lane
---@return biscide.Card?
function M.card(id, lane)
  local n = State.graph and State.graph.nodes[id]
  return n and State.cards:get(require("biscide.cards").key(n, lane))
end

--- The view as the GUI has it: the most rows a card may have, the
--- picker's sizes (its prompt's columns, its preview's columns and rows).
---@param o { max_rows?: integer, picker?: { cols: integer, preview_cols: integer, preview_rows: integer } }
function M.view(o)
  if o.picker then
    State.view.picker = o.picker
    require("biscide.picker").resize()
  end
  if o.max_rows and o.max_rows ~= State.view.max_rows then
    State.view.max_rows = math.max(3, o.max_rows)
    if State.lanes then
      view.render()
    end
  end
end

local group = vim.api.nvim_create_augroup("biscide", { clear = true })

--- The project file of buffer `buf`, if it is one of its Go or Rust files.
---@return string?
local function project_file(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  local rel = State.root and vim.fs.relpath(State.root, name)
  if rel and (name:match("%.go$") or name:match("%.rs$") or program.is_plain(rel)) then
    return rel
  end
end

--- A file of the project written: read again, the part under the cursor in
--- the middle.
---@param buf integer
local function on_write(buf)
  local rel = project_file(buf)
  if not rel then
    return
  end
  local row = vim.api.nvim_get_current_buf() == buf and vim.api.nvim_win_get_cursor(0)[1] - 1 or 0
  vim.schedule(function()
    program.written(rel, row)
  end)
end

--- A file of the project edited: read again from its buffer once the
--- typing pauses; in Insert mode, once it is left (code half typed reads
--- as something else: its card would shrink under the cursor). Its card
--- grows as it is typed in all the same (its range follows the edits).
local pending = {}
---@type table<integer, true> buffers typed in, read again when Insert mode is left
local typed = {}
---@param buf integer
local function on_change(buf)
  local rel = project_file(buf)
  if not rel then
    return
  end
  -- The card typed in keeps its whole part in its window, now.
  local card = State.cards:of_win(vim.api.nvim_get_current_win())
  if card then
    State.cards:fit(card)
  end
  if vim.fn.mode():match("^[iR]") then
    -- Read again later; the cards drawn now, the one typed in as tall as
    -- its text.
    typed[buf] = true
    State.stale[vim.api.nvim_buf_get_name(buf)] = true
    if State.lanes then
      view.render_soon()
    end
    return
  end
  if pending[buf] then
    return
  end
  pending[buf] = true
  vim.defer_fn(function()
    pending[buf] = nil
    if vim.api.nvim_buf_is_valid(buf) and not vim.fn.mode():match("^[iR]") then
      program.refresh(rel, buf)
    elseif vim.api.nvim_buf_is_valid(buf) then
      typed[buf] = true
    end
  end, 250)
end

--- Insert mode left: the buffers typed in read again.
local function on_insert_leave()
  for buf in pairs(typed) do
    typed[buf] = nil
    local rel = vim.api.nvim_buf_is_valid(buf) and project_file(buf)
    if rel then
      program.refresh(rel, buf)
    end
  end
end

--- biscide started on the project at `o.root`: read, laid out, `o.file` in
--- the middle (else the program's first declaration).
---@param o { root?: string, file?: string, max_rows?: integer }
function M.start(o)
  o = o or {}
  State.root = vim.fs.normalize(o.root or vim.uv.cwd())
  State.view.max_rows = o.max_rows or State.view.max_rows
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    callback = function(a)
      on_write(a.buf)
    end,
  })
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = group,
    callback = function(a)
      on_change(a.buf)
    end,
  })
  -- A new declaration written (insert mode left in the empty card): it
  -- becomes a card of its own; left empty, it goes.
  vim.api.nvim_create_autocmd("InsertLeave", {
    group = group,
    callback = function()
      local card = State.cards:of_win(vim.api.nvim_get_current_win())
      if card and card.key == Cards.NEW_KEY then
        typed = {}
        return navigate.leave_new()
      end
      on_insert_leave()
    end,
  })
  -- The language server's diagnostics of the active declaration's file
  -- changed: its missing names (biscide.missing) shown again.
  vim.api.nvim_create_autocmd("DiagnosticChanged", {
    group = group,
    callback = function(a)
      local n = State.active()
      if n and vim.api.nvim_buf_get_name(a.buf) == n.path then
        view.render_soon()
      end
    end,
  })
  -- What a card's lines take changed (a plugin set its gutter, its
  -- wrapping): the cards sized again.
  vim.api.nvim_create_autocmd("OptionSet", {
    group = group,
    pattern = vim.list_extend(vim.tbl_keys(Cards.WINDOW), { "showbreak", "breakindent", "breakindentopt" }),
    callback = function()
      if State.lanes then
        view.render_soon()
      end
    end,
  })
  -- What the cards' windows show changed: the GUI is told (once a tick).
  vim.api.nvim_create_autocmd({ "WinScrolled", "WinResized", "ModeChanged" }, {
    group = group,
    callback = function()
      if State.lanes then
        view.render_soon()
      end
    end,
  })
  local file = o.file and vim.fs.relpath(State.root, o.file)
  program.reload(file and { rel = file, row = 0 } or nil)
  vim.api.nvim_exec_autocmds("User", { pattern = "BiscideReady" })
end

return M
