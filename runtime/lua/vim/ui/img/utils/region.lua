---@class vim.ui.img.utils.Region
---@field x integer
---@field y integer
---@field width integer
---@field height integer
---@field unit vim.ui.img.utils.Unit
local M = {}
M.__index = M

---Creates a new instance of a region corresponding to an image.
---@param x integer
---@param y integer
---@param width integer
---@param height integer
---@param unit vim.ui.img.utils.Unit
---@return vim.ui.img.utils.Region
---@overload fun(opts:{x:integer, y:integer, width:integer, height:integer, unit:vim.ui.img.utils.Unit}):vim.ui.img.utils.Region
function M.new(x, y, width, height, unit)
  local instance = {}

  -- For overloaded function, options table provided
  if type(x) == 'table' and y == nil and width == nil and height == nil and unit == nil then
    instance = x
  else
    instance.x = x
    instance.y = y
    instance.width = width
    instance.height = height
    instance.unit = unit
  end

  vim.validate('region.x', instance.x, 'number')
  vim.validate('region.y', instance.y, 'number')
  vim.validate('region.width', instance.width, 'number')
  vim.validate('region.height', instance.height, 'number')
  vim.validate('region.unit', instance.unit, 'string')

  setmetatable(instance, M)
  return instance
end

---@param a vim.ui.img.utils.Region
---@param b vim.ui.img.utils.Region
---@return boolean
function M.__eq(a, b)
  if type(a) ~= 'table' or type(b) ~= 'table' then
    return false
  end

  return a.x == b.x
      and a.y == b.y
      and a.width == b.width
      and a.height == b.height
      and a.unit == b.unit
end

---Creates a new region from two positions.
---@param pos1 vim.ui.img.utils.Position
---@param pos2 vim.ui.img.utils.Position
---@return vim.ui.img.utils.Region
function M.from_positions(pos1, pos2)
  assert(pos1.unit == pos2.unit, 'positions must have same unit')
  local x, y = math.min(pos1.x, pos2.x), math.min(pos1.y, pos2.y)
  local w, h = math.max(pos1.x, pos2.x) - x, math.max(pos1.y, pos2.y) - y
  return M.new(x, y, w, h, pos1.unit)
end

---Convert unit of region to cells, returning a copy of the region.
---@return vim.ui.img.utils.Region
function M:to_cells()
  local screen = require('vim.ui.img.utils.screen')

  if self.unit == 'pixel' then
    local cell_x, cell_y = screen.pixels_to_cells(self.x, self.y)
    local cell_width, cell_height = screen.pixels_to_cells(self.width, self.height)
    return M.new(cell_x, cell_y, cell_width, cell_height, 'cell')
  end

  return self
end

---Convert unit of region to pixels, returning a copy of the region.
---@return vim.ui.img.utils.Region
function M:to_pixels()
  local screen = require('vim.ui.img.utils.screen')

  if self.unit == 'cell' then
    local px_x, px_y = screen.cells_to_pixels(self.x, self.y)
    local px_width, px_height = screen.cells_to_pixels(self.width, self.height)
    return M.new(px_x, px_y, px_width, px_height, 'pixel')
  end

  return self
end

---Returns a hash based on the region parameters.
---@return string
function M:hash()
  ---@type string[]
  local items = {
    tostring(self.x),
    tostring(self.y),
    tostring(self.width),
    tostring(self.height),
    tostring(self.unit),
  }
  return vim.fn.sha256(table.concat(items))
end

return M
