-- The program read: the whole project at the start (and on :BiscideReload);
-- one file again, from its buffer, as it is edited (the cards and the
-- links follow the typing) and when it is written.

local Cards = require("biscide.cards")
local State = require("biscide.state")
local graph = require("biscide.graph")
local navigate = require("biscide.navigate")
local view = require("biscide.view")

local M = {}

---@class biscide.Place
---@field rel string
---@field row integer from 0

--- Where the reader is: the active card's cursor, in its file.
---@return biscide.Place?
local function here()
  local n = State.active()
  if not n then
    return nil
  end
  local card = State.cards:get(Cards.key(n, "file"))
  local row = n.srow
  if card then
    row = n.srow + vim.api.nvim_win_get_cursor(card.win)[1] - 1
  end
  return { rel = n.rel, row = row }
end

--- Puts the declaration at `at` (else the program's first) in the middle.
---@param at biscide.Place?
local function arrive(at)
  local g = State.graph
  -- A file with no declarations of its own: the whole of it, a card.
  if at and not graph.at(g, at.rel, at.row) then
    return M.open(at.rel, at.row)
  end
  local id = (at and graph.at(g, at.rel, at.row)) or (g.nodes[1] and 1)
  State.lanes = nil
  if id then
    return navigate.go(id, "jump")
  end
  view.notice("No Go or Rust declarations here (tests and generated code are left out).")
  view.render()
end

--- Reads the whole program again; `at` (else where the reader is) in the
--- middle after.
---@param at biscide.Place?
function M.reload(at)
  if not State.root then
    return
  end
  at = at or here()
  State.building = true
  view.render()
  State.project = graph.project(State.root)
  State.graph = graph.build(State.project)
  State.building = false
  require("biscide.tree").set_files(State.root, State.project.files)
  arrive(at)
end

--- Whether file `rel` is open as a plain file (neither Go nor Rust: a card
--- of the whole file).
local function is_plain(rel)
  for _, s in ipairs(State.project and State.project.sources or {}) do
    if s.rel == rel then
      return s.lang == "text"
    end
  end
  return false
end
M.is_plain = is_plain

--- File `rel`'s outline read again (from `text`, else the file), the
--- others kept; the graph built anew.
local function reread(rel, text)
  local project = State.project
  local plain = is_plain(rel)
  local sources = vim.tbl_filter(function(s)
    return s.rel ~= rel
  end, project.sources)
  local fresh = graph.source(project, rel, text) or (plain and graph.plain_source(project, rel, text))
  if fresh then
    sources[#sources + 1] = fresh
  end
  table.sort(sources, function(a, b)
    return a.rel < b.rel
  end)
  project.sources = sources
  State.graph = graph.build(project)
end

--- The same node in a graph built anew: by its file and identity.
local function same(n)
  return n and graph.find(State.graph, { rel = n.rel, srow = n.srow, name = n.name, ident = n.ident })
end

--- File `rel` edited (its buffer `buf`): read again from the buffer, the
--- lanes laid out anew around the same card (no camera move: the reader is
--- typing).
---@param rel string
---@param buf integer
function M.refresh(rel, buf)
  if not State.project or not vim.tbl_contains(State.project.files, rel) then
    return
  end
  local active, prev = State.active(), State.lanes and State.graph.nodes[State.lanes.prev or -1]
  local cursor = State.cursor
  local cursor_node = cursor and cursor.node and State.graph.nodes[cursor.node]
  State.stale[vim.fs.joinpath(State.root, rel)] = nil
  -- The text as its file has it: each line ended.
  reread(rel, table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n") .. "\n")
  local id = same(active)
  if not id then
    -- The active declaration is gone (renamed): the part at the cursor.
    local win = vim.api.nvim_get_current_win()
    if vim.api.nvim_win_get_buf(win) == buf then
      id = graph.at(State.graph, rel, vim.api.nvim_win_get_cursor(win)[1] - 1)
    end
  end
  if not id then
    return M.reload()
  end
  if cursor_node then
    local c = same(cursor_node)
    State.cursor = c and { node = c, lane = cursor.lane } or nil
  end
  -- Typed in the active card, the cursor's line is read as another part
  -- now (text written past the end of its part): that part is the active
  -- one, the cursor goes with its text into its card.
  local win = vim.api.nvim_get_current_win()
  local typed = active and State.cards:of_win(win)
  local pos = vim.api.nvim_win_get_cursor(win)
  local moved
  if typed and typed.lane == "file" and vim.api.nvim_win_get_buf(win) == buf then
    local row = pos[1] - 1
    local n = State.graph.nodes[id]
    local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
    local at = graph.declaration_at(State.graph, rel, row)
    if line:find("%S") and (row < n.srow or row > n.erow) and at and at ~= id then
      id, moved = at, true
    end
  end
  -- The card typed in, its declaration renamed: still its card (its
  -- window kept, the cursor in it).
  -- The new declaration's card, what was written in it read: the card of
  -- that declaration now.
  local Cards = require("biscide.cards")
  local new_card = typed and typed.key == Cards.NEW_KEY
  if typed and typed.lane == "file" and (new_card or not moved) then
    State.cards:rekey(typed, Cards.key(State.graph.nodes[id], "file"))
  end
  if id ~= (active and active.id) then
    State.arrival = { how = "within", from = "file", direction = vim.NIL }
  end
  State.lanes = require("biscide.lanes").around(State.graph, id, same(prev))
  view.render()
  if moved and not new_card then
    local card = require("biscide.navigate").focus_active()
    if card then
      vim.api.nvim_win_set_cursor(card.win, pos)
    end
  end
end

--- File `rel` of the project written: read again; the part at `row` (from
--- 0) in the middle.
---@param rel string
---@param row integer
function M.written(rel, row)
  local project = State.project
  if not project then
    return
  end
  local at = { rel = rel, row = row }
  if not vim.tbl_contains(project.files, rel) then
    return M.reload(at)
  end
  reread(rel)
  if State.cursor and State.cursor.new then
    State.cursor, State.new_at = nil, nil
  end
  arrive(at)
  view.notice("Wrote " .. rel .. ".")
end

--- File `rel` opened: its declaration at `row` (else its first) in the
--- middle.
function M.open(rel, row)
  if not State.graph then
    return
  end
  local id = graph.at(State.graph, rel, row or 0)
  if id then
    return navigate.go(id, "jump")
  end
  -- Neither Go nor Rust (a configuration, a document): the whole file a
  -- card of its own.
  local source = graph.plain_source(State.project, rel)
  if not source then
    State.lanes = nil
    view.notice(rel .. " is not text.")
    return view.render()
  end
  table.insert(State.project.sources, source)
  if not vim.tbl_contains(State.project.files, rel) then
    table.insert(State.project.files, rel)
  end
  State.graph = graph.build(State.project)
  id = graph.at(State.graph, rel, row or 0)
  if id then
    navigate.go(id, "jump")
    local card = navigate.focus_active()
    if card and row then
      pcall(vim.api.nvim_win_set_cursor, card.win, { row + 1, 0 })
    end
  end
end

return M
