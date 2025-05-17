---@class vim.ui.img.utils.Size
---@field width integer
---@field height integer
---@field unit vim.ui.img.utils.Unit
local M = {}
M.__index = M

---Creates a new instance of a size corresponding to an image.
---@param width integer
---@param height integer
---@param unit vim.ui.img.utils.Unit
---@return vim.ui.img.utils.Size
---@overload fun(opts:{width:integer, height:integer, unit:vim.ui.img.utils.Unit}):vim.ui.img.utils.Size
function M.new(width, height, unit)
  local instance = {}

  -- For overloaded function, options table provided
  if type(width) == 'table' and height == nil and unit == nil then
    instance = width
  else
    instance.width = width
    instance.height = height
    instance.unit = unit
  end

  vim.validate('position.width', instance.width, 'number')
  vim.validate('position.height', instance.height, 'number')
  vim.validate('position.unit', instance.unit, 'string')

  setmetatable(instance, M)
  return instance
end

---@param a vim.ui.img.utils.Size
---@param b vim.ui.img.utils.Size
---@return boolean
function M.__eq(a, b)
  if type(a) ~= 'table' or type(b) ~= 'table' then
    return false
  end

  return a.width == b.width and a.height == b.height and a.unit == b.unit
end

---Convert unit of position to cells, returning a copy of the position.
---@return vim.ui.img.utils.Size
function M:to_cells()
  local screen = require('vim.ui.img.utils.screen')

  if self.unit == 'pixel' then
    local cell_width, cell_height = screen.pixels_to_cells(self.width, self.height)
    return M.new(cell_width, cell_height, 'cell')
  end

  return self
end

---Convert unit of position to pixels, returning a copy of the position.
---@return vim.ui.img.utils.Size
function M:to_pixels()
  local screen = require('vim.ui.img.utils.screen')

  if self.unit == 'cell' then
    local px_width, px_height = screen.cells_to_pixels(self.width, self.height)
    return M.new(px_width, px_height, 'pixel')
  end

  return self
end

---Returns a hash based on the position parameters.
---@return string
function M:hash()
  ---@type string[]
  local items = {
    tostring(self.width),
    tostring(self.height),
    tostring(self.unit),
  }
  return vim.fn.sha256(table.concat(items))
end

return M
