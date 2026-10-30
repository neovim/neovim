-- The lanes around a declaration, worked out from the graph (no side
-- effects): its file's declarations in source order; what uses it, by file
-- and line; what it uses, in the order its code uses them (those it does
-- not show, last); the one the reader came from.

local source = require("biscide.source")

--- The most cards a side lane holds.
local SIDE_MAX = 60

---@class biscide.Lanes
---@field active integer
---@field prev integer?
---@field used_by integer[]
---@field file integer[]
---@field uses integer[]
local Lanes = {}
Lanes.__index = Lanes

--- The lanes, left to right.
Lanes.ORDER = { "prev", "used_by", "file", "uses" }

local function uniq(list)
  local seen, out = {}, {}
  for _, v in ipairs(list) do
    if not seen[v] then
      seen[v] = true
      out[#out + 1] = v
    end
  end
  return out
end

local function capped(list)
  return vim.list_slice(list, 1, SIDE_MAX)
end

---@param graph table
---@param active integer
---@param prev integer?
---@return biscide.Lanes
function Lanes.around(graph, active, prev)
  local nodes = graph.nodes
  local a = nodes[active]
  local function by_place(x, y)
    local nx, ny = nodes[x], nodes[y]
    if nx.rel ~= ny.rel then
      return nx.rel < ny.rel
    end
    return nx.srow < ny.srow
  end
  local file = {}
  for _, n in ipairs(nodes) do
    if n.rel == a.rel then
      file[#file + 1] = n.id
    end
  end
  table.sort(file, by_place)
  local used_by = uniq(vim.tbl_map(function(e)
    return e.from
  end, a.inc))
  table.sort(used_by, by_place)
  local uses = uniq(vim.tbl_map(function(e)
    return e.to
  end, a.out))
  local at = {}
  for _, u in ipairs(uses) do
    local p = source.first_use(a, nodes[u].short)
    at[u] = p and (p[1] * 100000 + p[2]) or math.huge
  end
  table.sort(uses, function(x, y)
    if at[x] ~= at[y] then
      return at[x] < at[y]
    end
    return by_place(x, y)
  end)
  return setmetatable({
    active = active,
    prev = (prev and prev ~= active) and prev or nil,
    used_by = capped(used_by),
    file = file,
    uses = capped(uses),
  }, Lanes)
end

--- A lane's declarations, top to bottom.
---@param lane biscide.Lane
---@return integer[]
function Lanes:of(lane)
  if lane == "prev" then
    return self.prev and { self.prev } or {}
  end
  return self[lane] or {}
end

return Lanes
