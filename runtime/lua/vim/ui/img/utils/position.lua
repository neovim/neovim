---@class vim.ui.img.utils.Position
---@field x integer
---@field y integer
---@field unit vim.ui.img.utils.Unit
local M = {}
M.__index = M

---Creates a new instance of a position corresponding to an image.
---@param x integer
---@param y integer
---@param unit vim.ui.img.utils.Unit
---@return vim.ui.img.utils.Position
---@overload fun(opts:{x:integer, y:integer, unit:vim.ui.img.utils.Unit}):vim.ui.img.utils.Position
function M.new(x, y, unit)
  local instance = {}

  -- For overloaded function, options table provided
  if type(x) == 'table' and y == nil and unit == nil then
    instance = x
  else
    instance.x = x
    instance.y = y
    instance.unit = unit
  end

  vim.validate('position.x', instance.x, 'number')
  vim.validate('position.y', instance.y, 'number')
  vim.validate('position.unit', instance.unit, 'string')

  setmetatable(instance, M)
  return instance
end

---@param a vim.ui.img.utils.Position
---@param b vim.ui.img.utils.Position
---@return boolean
function M.__eq(a, b)
  if type(a) ~= 'table' or type(b) ~= 'table' then
    return false
  end

  return a.x == b.x and a.y == b.y and a.unit == b.unit
end

---Convert unit of position to cells, returning a copy of the position.
---@return vim.ui.img.utils.Position
function M:to_cells()
  local screen = require('vim.ui.img.utils.screen')

  if self.unit == 'pixel' then
    local cell_x, cell_y = screen.pixels_to_cells(self.x, self.y)
    return M.new(cell_x, cell_y, 'cell')
  end

  return self
end

---Convert unit of position to pixels, returning a copy of the position.
---@return vim.ui.img.utils.Position
function M:to_pixels()
  local screen = require('vim.ui.img.utils.screen')

  if self.unit == 'cell' then
    local px_x, px_y = screen.cells_to_pixels(self.x, self.y)
    return M.new(px_x, px_y, 'pixel')
  end

  return self
end

---Returns a hash based on the position parameters.
---@return string
function M:hash()
  ---@type string[]
  local items = {
    tostring(self.x),
    tostring(self.y),
    tostring(self.unit),
  }
  return vim.fn.sha256(table.concat(items))
end

return M
