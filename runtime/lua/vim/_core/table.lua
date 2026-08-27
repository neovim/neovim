-- Basic shim for LuaJIT's table.new and table.clear.
local has_new, new = pcall(require, 'table.new')
local has_clear, clear = pcall(require, 'table.clear')

local M = {}

if not has_new then
  ---@diagnostic disable-next-line: unused-local
  new = function(narr, nrec)
    return {}
  end
end

if not has_clear then
  clear = function(tab)
    ---@diagnostic disable-next-line: no-unknown
    for k in pairs(tab) do
      ---@diagnostic disable-next-line: no-unknown
      tab[k] = nil
    end
  end
end

M.new = new
M.clear = clear

return M
