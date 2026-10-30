-- Moving through the program: the active declaration (its card's window
-- Nvim's current one), the card cursor (it marks a card; going there makes
-- it the active one), the history. Each action changes the state
-- (biscide.state) and asks the view to show it.

local Cards = require("biscide.cards")
local Lanes = require("biscide.lanes")
local State = require("biscide.state")
local graph = require("biscide.graph")
local view = require("biscide.view")

local M = {}

--- The camera to the card cursor's card (the GUI follows it).
local function follow()
  State.generation.focus = State.generation.focus + 1
end

--- The active card's window, Nvim's current one.
function M.focus_active()
  local n = State.active()
  local card = n and State.cards:get(Cards.key(n, "file"))
  if card then
    vim.api.nvim_set_current_win(card.win)
  end
  return card
end

---@alias biscide.Arrival "jump"|"side"|"within"

--- Makes declaration `id` the active one: the lanes laid out around it, its
--- card's window Nvim's current one (the cursor on its name when newly
--- gone to). `how`: from elsewhere ("jump"), from a side lane ("side"),
--- from the file lane ("within": the previous one stays). `opts.record`
--- false: not remembered in the history (walking it).
---@param id integer
---@param how? biscide.Arrival
---@param opts? { record?: boolean, from?: biscide.Lane, direction?: "back"|"forward" }
function M.go(id, how, opts)
  local n = State.graph and State.graph.nodes[id]
  if not n then
    return
  end
  opts = opts or {}
  -- How it came, for the GUI to move the same way: from a card of lane
  -- `from`, or back or forth (a jump goes forth).
  State.arrival = {
    how = how or "jump",
    from = opts.from or vim.NIL,
    direction = opts.direction or ((how or "jump") == "jump" and "forward" or vim.NIL),
  }
  local old = State.lanes and State.lanes.active
  if old ~= id then
    State.cursor = nil
    if opts.record ~= false then
      local short = n.kind == "file" and n.name or n.name:match("([^.]+)$")
      State.history:push({ rel = n.rel, srow = n.srow, name = n.name, short = short, ident = n.ident })
    end
  end
  local prev = State.lanes and State.lanes.prev
  local nodes = State.graph.nodes
  if (how or "jump") ~= "within" and old and old ~= id and nodes[old].rel ~= n.rel then
    prev = old
  end
  State.lanes = Lanes.around(State.graph, id, prev)
  State.generation.centre = State.generation.centre + 1
  view.render()
  local card = M.focus_active()
  if card and old ~= id then
    pcall(vim.api.nvim_win_set_cursor, card.win, { n.nrow + 1, n.ncol })
  end
  vim.api.nvim_exec_autocmds("User", {
    pattern = "BiscideActive",
    data = { name = n.name, path = n.rel, line = n.srow + 1 },
  })
end

--- Back to the declaration the reader came from.
function M.back()
  if State.lanes and State.lanes.prev then
    M.go(State.lanes.prev, "side", { from = "prev", direction = "back" })
  end
end

--- To the history's entry `k`.
---@param k integer
function M.history_to(k)
  local h = State.history
  local entry = h.list[k]
  if not entry or (k == h.at and State.lanes) then
    return
  end
  local id = graph.find(State.graph, entry)
  if not id then
    return view.notice("That declaration is gone.")
  end
  local direction = k < h.at and "back" or "forward"
  h.at = k
  M.go(id, "jump", { record = false, direction = direction })
end

--- `by` entries back (negative) or forth through the history.
function M.history(by)
  M.history_to(State.history:step(by))
end

-- ---- The card cursor ----

---@param id integer
---@param lane biscide.Lane
--- `stay`: the camera stays (the GUI brought the card to it).
local function set_cursor(id, lane, stay)
  local on_active = lane == "file" and State.lanes and id == State.lanes.active
  State.cursor = (not on_active) and { node = id, lane = lane } or nil
  if not stay then
    follow()
  end
  view.render()
end

---@return biscide.Lane
local function cursor_lane()
  local c = State.cursor
  return (c and c.lane) or "file"
end

--- The lane's cards stepped `by` (down when positive); in the file lane,
--- past its last card onto the empty one.
local function step(by)
  local lanes = State.lanes
  local lane = cursor_lane()
  local nodes = lanes:of(lane)
  local from
  if State.cursor and State.cursor.new then
    from = #nodes + 1
  else
    local at = State.cursor and State.cursor.node or lanes.active
    for k, id in ipairs(nodes) do
      if id == at then
        from = k
      end
    end
  end
  if not from then
    return
  end
  local to = math.max(1, from + by)
  if lane == "file" and to > #nodes then
    State.cursor = { new = true }
    follow()
    return view.render()
  end
  set_cursor(nodes[math.min(to, #nodes)], lane)
end

--- Into the next lane with cards on the left (-1) or right (1), on its
--- card nearest the card cursor's place in its own lane.
local function sideways(dir)
  local lanes = State.lanes
  local from = cursor_lane()
  local at = 0
  for k, l in ipairs(Lanes.ORDER) do
    if l == from then
      at = k
    end
  end
  local share = 0.5
  local here = lanes:of(from)
  local current = State.cursor and State.cursor.node or lanes.active
  for k, id in ipairs(here) do
    if id == current and #here > 1 then
      share = (k - 1) / (#here - 1)
    end
  end
  for k = at + dir, dir > 0 and #Lanes.ORDER or 1, dir do
    local lane = Lanes.ORDER[k]
    if lane == "file" then
      State.cursor = nil
      follow()
      return view.render()
    end
    local nodes = lanes:of(lane)
    if #nodes > 0 then
      return set_cursor(nodes[1 + math.floor(share * (#nodes - 1) + 0.5)], lane)
    end
  end
end

---@alias biscide.LaneMove "down"|"up"|"left"|"right"|"top"|"bottom"|"uses"|"used_by"

--- Moves the card cursor.
---@param dir biscide.LaneMove
---@param count? integer
function M.lane(dir, count)
  if not State.lanes then
    return
  end
  count = count or 1
  if dir == "down" or dir == "up" then
    step(dir == "down" and count or -count)
  elseif dir == "left" or dir == "right" then
    for _ = 1, count do
      sideways(dir == "left" and -1 or 1)
    end
  elseif dir == "top" or dir == "bottom" then
    local nodes = State.lanes:of(cursor_lane())
    if #nodes > 0 then
      set_cursor(dir == "top" and nodes[1] or nodes[#nodes], cursor_lane())
    end
  elseif dir == "uses" or dir == "used_by" then
    local nodes = State.lanes:of(dir)
    if #nodes == 0 then
      return view.notice(dir == "uses" and "It uses nothing shown." or "Nothing shown uses it.")
    end
    set_cursor(nodes[1], dir)
  end
end

--- To the card under the card cursor (on the empty card: a new
--- declaration); whether there was a card cursor.
---@return boolean
function M.go_cursor()
  local c = State.cursor
  if not c then
    return false
  end
  if c.new then
    M.new()
  else
    M.go(c.node, c.lane == "file" and "within" or "side", { from = c.lane })
  end
  return true
end

--- The card cursor dropped; whether there was one.
function M.drop_cursor()
  if not State.cursor then
    return false
  end
  State.cursor = nil
  follow()
  view.render()
  return true
end

--- The camera back on the active card.
function M.centre()
  State.cursor = nil
  State.generation.centre = State.generation.centre + 1
  view.render()
end

--- A card clicked once (or a name it has, in the active card's code): the
--- card cursor on it; `stay`: the camera stays where it is.
function M.mark(id, lane, stay)
  -- A missing declaration's card (its id negative): resolving it.
  if id < 0 then
    return require("biscide.missing").open(id)
  end
  set_cursor(id, lane, stay)
end

--- A card clicked twice: it becomes the active one.
function M.activate(id, lane)
  if id < 0 then
    return require("biscide.missing").open(id)
  end
  M.go(id, lane == "file" and "within" or "side", { from = lane })
end

--- A new declaration at the end of the active one's file, in the empty
--- card: its lines (`text`, else an empty one) added to the real file (a
--- blank line before), insert mode at `at` in them (row from 1, byte; else
--- the start).
---@param text? string[]
---@param at? { [1]: integer, [2]: integer }
function M.new(text, at)
  local n = State.active()
  if not n then
    return
  end
  local buf = Cards.buffer(n.path)
  local last = vim.api.nvim_buf_line_count(buf)
  local tail = vim.api.nvim_buf_get_lines(buf, last - 1, last, false)[1] or ""
  local lines = text or { "" }
  local add = tail == "" and {} or { "" }
  vim.list_extend(add, lines)
  vim.api.nvim_buf_set_lines(buf, last, last, false, add)
  local row = last + #add - #lines
  State.cursor = { new = true }
  State.new_at = { path = n.path, srow = row, erow = row + #lines - 1, lead = #add - #lines }
  follow()
  view.render()
  local card = State.cards:get(Cards.NEW_KEY)
  if not card then
    return
  end
  vim.api.nvim_set_current_win(card.win)
  at = at or { 1, 0 }
  local line = lines[at[1]] or ""
  vim.api.nvim_win_set_cursor(card.win, { row + at[1], math.min(at[2], #line) })
  if at[2] >= #line then
    vim.cmd.startinsert({ bang = true })
  else
    vim.cmd.startinsert()
  end
end

--- The new declaration left (insert mode left in its card): written, it
--- is read and becomes a card of its own; left empty, its lines go (and
--- the blank line before them that was added), the file as it was.
function M.leave_new()
  local w = State.new_at
  if not w then
    return
  end
  State.cursor, State.new_at = nil, nil
  local card = State.cards:get(Cards.NEW_KEY)
  local s, e = w.srow, w.erow
  if card then
    local cs, ce = require("biscide.narrow").rows(card.win)
    s, e = cs or s, ce or e
  end
  local buf = Cards.buffer(w.path)
  local text = table.concat(vim.api.nvim_buf_get_lines(buf, s, e + 1, false), "")
  local rel = State.root and vim.fs.relpath(State.root, w.path)
  if not text:find("%S") then
    local from = s - (w.lead or 0)
    local below = vim.api.nvim_buf_get_lines(buf, e + 1, -1, false)
    -- Only at the file's end, as it was added.
    if not table.concat(below, ""):find("%S") then
      vim.api.nvim_buf_set_lines(buf, from, -1, false, {})
    end
    view.render()
    M.focus_active()
    return
  end
  vim.schedule(function()
    if rel then
      local program = require("biscide.program")
      program.refresh(rel, buf)
      program.open(rel, s)
    end
  end)
end

return M
