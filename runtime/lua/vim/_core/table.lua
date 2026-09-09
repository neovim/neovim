-- Basic shim for LuaJIT's table.new and table.clear.
local has_new, new = pcall(require, 'table.new')
local has_clear, clear = pcall(require, 'table.clear')

local M = {}

if not has_new then
  new = function(_narr, _nrec)
    return {}
  end
end

if not has_clear then
  clear = function(tab)
    for k in pairs(tab) do
      tab[k] = nil
    end
  end
end

---@cast new fun(narr: integer, nrec: integer): table
---@cast clear fun(tab: table)
M.new = new
M.clear = clear

return M
