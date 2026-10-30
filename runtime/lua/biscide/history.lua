-- The declarations gone to, as a jumplist: going somewhere new from the
-- middle of it drops what was ahead; walking it adds nothing.

---@class biscide.HistoryEntry
---@field rel string
---@field srow integer
---@field name string
---@field short? string its name as the history shows it
---@field ident? string

---@class biscide.History
---@field list biscide.HistoryEntry[]
---@field at integer the entry the reader is at (0: none)
---@field max integer
local History = {}
History.__index = History

---@param max? integer
---@return biscide.History
function History.new(max)
  return setmetatable({ list = {}, at = 0, max = max or 100 }, History)
end

---@param a biscide.HistoryEntry
---@param b biscide.HistoryEntry?
local function same(a, b)
  return b ~= nil and a.rel == b.rel and a.srow == b.srow
end

--- Remembers `entry` gone to, after the current one.
---@param entry biscide.HistoryEntry
function History:push(entry)
  if same(entry, self.list[self.at]) then
    return
  end
  for k = #self.list, self.at + 1, -1 do
    self.list[k] = nil
  end
  self.list[#self.list + 1] = entry
  if #self.list > self.max then
    table.remove(self.list, 1)
  end
  self.at = #self.list
end

--- The index `by` entries away from the current one, within the list.
---@param by integer
---@return integer
function History:step(by)
  return math.max(1, math.min(#self.list, self.at + by))
end

--- The entries' names as the history shows them: a method's without its
--- type, a file's whole.
---@return string[]
function History:names()
  return vim.tbl_map(function(e)
    return e.short or e.name
  end, self.list)
end

return History
