-- biscide's state, in one place, as Nvim keeps its own (curbuf, curwin, the
-- buffer and window lists): the project and its graph, the lanes, the card
-- cursor, the history, the cards' windows, what the view may hold. The
-- tree and the picker keep theirs in their modules (biscide.tree,
-- biscide.picker).

local History = require("biscide.history")

---@alias biscide.Lane "prev"|"used_by"|"file"|"uses"

---@class biscide.Cursor
---@field node? integer the card cursor's declaration (with `lane`)
---@field lane? biscide.Lane
---@field new? boolean on the empty card at the file lane's end

---@class biscide.View
---@field max_rows integer the most rows a card may have
---@field picker? { cols: integer, preview_cols: integer, preview_rows: integer } the picker's sizes

---@class biscide.Generation  counters the UI watches
---@field centre integer the camera back on the active card
---@field focus integer the camera onto the card cursor's card

---@class biscide.State
---@field root string?
---@field project table?
---@field graph table?
---@field lanes biscide.Lanes?
---@field cursor biscide.Cursor?
---@field history biscide.History
---@field cards biscide.Cards
---@field view biscide.View
---@field generation biscide.Generation
---@field building boolean
---@field notice string?
---@field new_at? { path: string, srow: integer } where a new declaration is written
---@field stale table<string, true> files typed in since they were read (their declarations' rows are old: their cards keep their windows' ranges, which follow the edits)
---@field arrival? { how: biscide.Arrival, from: biscide.Lane?, direction: ("back"|"forward")? } how the active one came
local State = {
  root = nil,
  project = nil,
  graph = nil,
  lanes = nil,
  cursor = nil,
  history = History.new(100),
  cards = require("biscide.cards").new(),
  view = { max_rows = 40 },
  generation = { centre = 0, focus = 0 },
  building = false,
  stale = {},
  notice = nil,
}

--- The active declaration's node, if any.
---@return table?
function State.active()
  return State.lanes and State.graph.nodes[State.lanes.active]
end

--- An option of biscide's (`vim.g.biscide_<name>`), else `default`.
---@param name string
---@param default any
function State.option(name, default)
  local v = vim.g["biscide_" .. name]
  if v == nil then
    return default
  end
  return v
end

return State
