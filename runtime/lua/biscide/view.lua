-- The presenter: the state (biscide.state) shown. `render` lays the cards'
-- windows out for the lanes, marks in the code the names that link them,
-- and tells the GUI (`vim._gui_send("state", …)`), which paints the
-- windows' grids as cards and draws the curves. Anything that changes the
-- state asks for a render; `render_soon` coalesces the asks of one tick.

local Cards = require("biscide.cards")
local Lanes = require("biscide.lanes")
local State = require("biscide.state")
local narrow = require("biscide.narrow")
local graph = require("biscide.graph")
local source = require("biscide.source")

local M = {}

--- Tells the GUI (`nvim --gui`) a payload; nothing without one.
---@param kind string
---@param payload any
function M.send(kind, payload)
  if vim._gui_send then
    vim._gui_send(kind, payload)
  end
end

--- Says `msg` on Nvim's message line.
function M.notice(msg)
  State.notice = msg
  vim.api.nvim_echo({ { msg } }, false, {})
end

-- ---- The names that link the cards ----

local links_ns = vim.api.nvim_create_namespace("biscide_links")
---@type table<integer, true>
local marked = {}

local LINK_GROUP = {
  call = "BiscideLinkCall",
  parameter = "BiscideLinkParameter",
  field = "BiscideLinkField",
  type_use = "BiscideLinkTypeUse",
  reference = "BiscideLinkReference",
  receiver = "BiscideLinkReceiver",
}

---@param e table a graph edge
local function link_group(e)
  if e.violation then
    return "BiscideLinkOutward"
  end
  for _, k in ipairs(graph.KINDS) do
    if e.kinds[k] then
      return LINK_GROUP[k]
    end
  end
  return "BiscideLinkReference"
end

---@param e table
local function kinds_of(e)
  return vim.tbl_filter(function(k)
    return e.kinds[k]
  end, graph.KINDS)
end

--- The edge from `user` to `used`, if any.
local function edge(user, used)
  for _, e in ipairs(State.graph.nodes[user].out) do
    if e.to == used then
      return e
    end
  end
end

--- Marks every use of `name` in node `n`'s code (in card `card`'s buffer,
--- the real file's) in `group`.
local function mark(card, n, name, group)
  marked[card.buf] = true
  for _, u in ipairs(source.uses(n, name)) do
    pcall(vim.api.nvim_buf_set_extmark, card.buf, links_ns, n.srow + u[1], u[2], {
      end_col = u[3],
      hl_group = group,
      priority = 250,
    })
  end
end

--- In the active card, each name its uses lane shows; in each card of the
--- used-by lane, the active declaration's name. And the links as the GUI
--- draws them: how, and where the user's code names the used one.
---@param lanes biscide.Lanes
---@param cards table<string, biscide.Card>
local function links(lanes, cards)
  for buf in pairs(marked) do
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_clear_namespace(buf, links_ns, 0, -1)
    end
  end
  marked = {}
  local nodes = State.graph.nodes
  local a = nodes[lanes.active]
  local out = {}
  local function link(lane, user, used, card_of_user)
    local e = edge(user, used)
    if not e then
      return
    end
    local at = source.first_use(nodes[user], nodes[used].short)
    if card_of_user then
      mark(card_of_user, nodes[user], nodes[used].short, link_group(e))
    end
    out[#out + 1] = {
      node = lane == "uses" and used or user,
      column = lane,
      kinds = kinds_of(e),
      violation = e.violation,
      -- The row in the user's file (its card's buffer), from 0.
      row = at and (nodes[user].srow + at[1]) or -1,
      col = at and at[2] or -1,
    }
  end
  local active_card = cards[Cards.key(a, "file")]
  for _, u in ipairs(lanes.uses) do
    link("uses", lanes.active, u, active_card)
  end
  for _, u in ipairs(lanes.used_by) do
    link("used_by", u, lanes.active, cards[Cards.key(nodes[u], "used_by")])
  end
  return out
end

-- ---- Rendering ----

local function node_info(id)
  local n = State.graph.nodes[id]
  return {
    id = id,
    name = n.name,
    short = n.short,
    kind = n.kind,
    rel = n.rel,
    line = n.srow + 1,
    lines = n.erow - n.srow + 1,
    used_by = #n.inc,
    uses = #n.out,
    layer = n.layer or vim.NIL,
  }
end

--- The key of the card the camera follows: the card cursor's, else the
--- active one's.
local function followed(lanes)
  local c = State.cursor
  if c and c.new then
    return Cards.NEW_KEY
  end
  if c then
    return Cards.key(State.graph.nodes[c.node], c.lane)
  end
  return Cards.key(State.graph.nodes[lanes.active], "file")
end

--- The lines a new declaration is being written in (its file, rows from
--- 0), if one is.
---@return { path: string, srow: integer, erow: integer }?
local function writing()
  local w = State.cursor and State.cursor.new and State.new_at
  if not w then
    return nil
  end
  local s, e = w.srow, w.erow or w.srow
  local card = State.cards:get(Cards.NEW_KEY)
  if card then
    local cs, ce = narrow.rows(card.win)
    s, e = cs or s, ce or e
  end
  return { path = w.path, srow = s, erow = e }
end

--- The lanes as shown: while a new declaration is written, what the
--- program reads of its lines is its card's, not cards of their own.
---@param lanes biscide.Lanes
---@param w? { path: string, srow: integer, erow: integer }
---@return biscide.Lanes
local function shown(lanes, w)
  if not w then
    return lanes
  end
  local nodes = State.graph.nodes
  local function keep(id)
    local n = nodes[id]
    return not (n.path == w.path and n.erow >= w.srow and n.srow <= w.erow)
  end
  local out = setmetatable({ active = lanes.active }, getmetatable(lanes))
  out.prev = lanes.prev and keep(lanes.prev) and lanes.prev or nil
  for _, lane in ipairs({ "used_by", "file", "uses" }) do
    out[lane] = vim.tbl_filter(keep, lanes[lane])
  end
  return out
end

--- Lays the cards out and tells the GUI.
function M.render()
  if not State.lanes then
    M.send("state", { building = State.building, notice = State.notice or vim.NIL, root = State.root or vim.NIL })
    return
  end
  source.clear()
  local w = writing()
  local lanes = shown(State.lanes, w)
  local nodes = State.graph.nodes
  local view = { max_rows = State.view.max_rows, cols = State.option("card_cols", 80) }
  local placed, keep, info = {}, {}, {}
  local by_key = {}
  -- Whether no part of a file but `n` has rows `from..to`.
  local function free_of(n)
    return function(from, to)
      for _, o in ipairs(nodes) do
        if o ~= n and o.path == n.path and o.srow <= to and o.erow >= from then
          return false
        end
      end
      return true
    end
  end
  for _, lane in ipairs(Lanes.ORDER) do
    for _, id in ipairs(lanes:of(lane)) do
      local card = State.cards:place_part(nodes[id], lane, view, free_of(nodes[id]))
      keep[card.key], by_key[card.key] = true, card
      placed[#placed + 1] =
        { key = card.key, node = id, column = lane, win = card.win, rows = card.rows, textoff = card.textoff }
      info[tostring(id)] = node_info(id)
      -- Typed in since it was read: its lines as its window has them.
      if State.stale[nodes[id].path] then
        local s, e = narrow.rows(card.win)
        if s then
          info[tostring(id)].line, info[tostring(id)].lines = s + 1, e - s + 1
        end
      end
    end
  end
  local link_list = links(lanes, by_key)
  -- What the active declaration names that is nowhere (the language
  -- server says so): a card each, after what it uses.
  local uses = vim.list_slice(lanes.uses, 1, #lanes.uses)
  -- (Finding them may fail on code half typed: the cards go on without.)
  -- (Typed in since it was read, the ones found then.)
  local stale = State.stale[nodes[lanes.active].path] ~= nil
  local ok, missing = pcall(require("biscide.missing").cards, nodes[lanes.active], view, stale)
  for _, m in ipairs(ok and missing or {}) do
    keep[m.card.key] = true
    placed[#placed + 1] = {
      key = m.card.key,
      node = m.id,
      column = "uses",
      win = m.card.win,
      rows = m.card.rows,
      textoff = m.card.textoff,
    }
    info[tostring(m.id)] = m.info
    uses[#uses + 1] = m.id
    link_list[#link_list + 1] = m.link
  end
  -- Where each link starts in the active card: the row of its window
  -- (its part's lines before it may wrap in more rows than one).
  local active_card = by_key[Cards.key(nodes[lanes.active], "file")]
  for _, l in ipairs(link_list) do
    if active_card and l.column == "uses" and l.row >= 0 then
      local s = nodes[lanes.active].srow
      local ok, h = pcall(vim.api.nvim_win_text_height, active_card.win, { start_row = s, end_row = l.row - 1, start_vcol = 0 })
      l.vrow = l.row <= s and 0 or (ok and h.all) or (l.row - s)
      -- Its column as shown (tabs are wide).
      local line = vim.api.nvim_buf_get_lines(active_card.buf, l.row, l.row + 1, false)[1] or ""
      l.vcol = vim.api.nvim_win_call(active_card.win, function()
        return vim.fn.strdisplaywidth(line:sub(1, l.col))
      end)
    end
  end
  -- The empty card: on the lines a new declaration is written in.
  local new
  if w then
    new = State.cards:place_new(w.path, w.srow, w.erow, view)
    keep[new.key] = true
  end
  State.cards:retain(keep)
  local c = State.cursor
  M.send("state", {
    root = State.root,
    building = State.building,
    notice = State.notice or vim.NIL,
    active = lanes.active,
    prev = lanes.prev or vim.NIL,
    lanes = { file = lanes.file, used_by = lanes.used_by, uses = uses },
    cards = placed,
    nodes = info,
    links = link_list,
    cursor = c and (c.new and { new = true } or { node = c.node, column = c.lane }) or vim.NIL,
    follow = followed(lanes),
    arrival = State.arrival or vim.NIL,
    history = { names = State.history:names(), at = State.history.at },
    new_card = new and { win = new.win, rows = new.rows } or vim.NIL,
    centre = State.generation.centre,
    focus = State.generation.focus,
    declarations = #vim.tbl_filter(function(n)
      return not n.part
    end, nodes),
  })
end

local pending = false
--- `render`, once, after what runs now.
function M.render_soon()
  if pending then
    return
  end
  pending = true
  vim.schedule(function()
    pending = false
    M.render()
  end)
end

return M
