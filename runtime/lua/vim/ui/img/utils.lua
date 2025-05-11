local M = {}

---@alias vim.ui.img.Unit 'cell'|'pixel'

---Convert an integer representing absolute pixels to a cell.
---@param x integer
---@param y integer
---@return integer x, integer y
local function pixels_to_cells(x, y)
  local size = require('vim.ui.img.screen').size()
  return math.floor(x / size.cell_width), math.floor(y / size.cell_height)
end

---Convert an integer representing a cell to absolute pixels.
---@param x integer
---@param y integer
---@return integer x, integer y
local function cells_to_pixels(x, y)
  local size = require('vim.ui.img.screen').size()
  return math.floor(x * size.cell_width), math.floor(y * size.cell_height)
end

---Creates a new instance of a position corresponding to an image.
---@param x integer
---@param y integer
---@param unit vim.ui.img.Unit
---@return vim.ui.img.utils.Position
---@overload fun(opts:{x:integer, y:integer, unit:vim.ui.img.Unit}):vim.ui.img.utils.Position
function M.new_position(x, y, unit)
  ---@class (exact) vim.ui.img.utils.Position
  ---@field x integer
  ---@field y integer
  ---@field unit vim.ui.img.Unit
  local position = { x = x, y = y, unit = unit }

  -- For overloaded function, options table provided
  if type(x) == 'table' and y == nil and unit == nil then
    position = x
  end

  vim.validate('position.x', position.x, 'number')
  vim.validate('position.y', position.y, 'number')
  vim.validate('position.unit', position.unit, 'string')

  ---Convert unit of position to cells, returning a copy of the position.
  ---@return vim.ui.img.utils.Position
  function position:to_cells()
    if self.unit == 'pixel' then
      local cell_x, cell_y = pixels_to_cells(self.x, self.y)
      return M.new_position(cell_x, cell_y, 'cell')
    end

    return self
  end

  ---Convert unit of position to pixels, returning a copy of the position.
  ---@return vim.ui.img.utils.Position
  function position:to_pixels()
    if self.unit == 'cell' then
      local px_x, px_y = cells_to_pixels(self.x, self.y)
      return M.new_position(px_x, px_y, 'pixel')
    end

    return self
  end

  ---Returns a hash based on the position parameters.
  ---@return string
  function position:hash()
    ---@type string[]
    local items = {
      tostring(self.x),
      tostring(self.y),
      tostring(self.unit),
    }
    return vim.fn.sha256(table.concat(items))
  end

  return position
end

---Creates a new instance of a region corresponding to an image.
---@param pos1 vim.ui.img.utils.Position
---@param pos2 vim.ui.img.utils.Position
---@return vim.ui.img.utils.Region
---@overload fun(opts:{pos1:vim.ui.img.utils.Position, pos2:vim.ui.img.utils.Position}):vim.ui.img.utils.Region
function M.new_region(pos1, pos2)
  ---@class (exact) vim.ui.img.utils.Region
  ---@field pos1 vim.ui.img.utils.Position
  ---@field pos2 vim.ui.img.utils.Position
  local region = { pos1 = pos1, pos2 = pos2 }

  -- For overloaded function, options table provided
  if type(pos1) == 'table' and pos2 == nil then
    ---@cast pos1 table
    region = pos1
  end

  vim.validate('region.pos1', region.pos1, 'table')
  vim.validate('region.pos2', region.pos2, 'table')

  region.pos1 = M.new_position(region.pos1)
  region.pos2 = M.new_position(region.pos2)

  assert(
    region.pos1.unit == region.pos2.unit,
    'units of pos1 and pos2 do not match'
  )

  ---Convert unit of region to cells, returning a copy of the region.
  ---@return vim.ui.img.utils.Region
  function region:to_cells()
    return M.new_region(
      self.pos1:to_cells(),
      self.pos2:to_cells()
    )
  end

  ---Convert unit of region to pixels, returning a copy of the region.
  ---@return vim.ui.img.utils.Region
  function region:to_pixels()
    return M.new_region(
      self.pos1:to_pixels(),
      self.pos2:to_pixels()
    )
  end

  ---Returns the x, y, width, height of the region.
  ---@return integer x, integer y, integer width, integer height
  function region:to_bounds()
    local p1 = self.pos1
    local p2 = self.pos2

    local x = math.min(p1.x, p2.x)
    local y = math.min(p1.y, p2.y)
    local width = math.abs(p1.x - p2.x)
    local height = math.abs(p1.y - p2.y)

    return x, y, width, height
  end

  ---Returns a hash based on the region parameters.
  ---@return string
  function region:hash()
    ---@type string[]
    local items = {
      self.pos1:hash(),
      self.pos2:hash(),
    }
    return vim.fn.sha256(table.concat(items))
  end

  return region
end

---Creates a new instance of an size corresponding to an image.
---@param width integer
---@param height integer
---@param unit vim.ui.img.Unit
---@return vim.ui.img.utils.Size
---@overload fun(opts:{width:integer, height:integer, unit:vim.ui.img.Unit}):vim.ui.img.utils.Size
function M.new_size(width, height, unit)
  ---@class (exact) vim.ui.img.utils.Size
  ---@field width integer
  ---@field height integer
  ---@field unit vim.ui.img.Unit
  local size = { width = width, height = height, unit = unit }

  -- For overloaded function, options table provided
  if type(width) == 'table' and height == nil and unit == nil then
    size = width
  end

  vim.validate('size.width', size.width, 'number')
  vim.validate('size.height', size.height, 'number')
  vim.validate('size.unit', size.unit, 'string')

  ---Convert unit of size to cells, returning a copy of the size.
  ---@return vim.ui.img.utils.Size
  function size:to_cells()
    if self.unit == 'pixel' then
      local cell_width, cell_height = pixels_to_cells(self.width, self.height)
      return M.new_size(cell_width, cell_height, 'cell')
    end

    return self
  end

  ---Convert unit of size to pixels, returning a copy of the size.
  ---@return vim.ui.img.utils.Size
  function size:to_pixels()
    if self.unit == 'cell' then
      local px_width, px_height = cells_to_pixels(self.width, self.height)
      return M.new_size(px_width, px_height, 'pixel')
    end

    return self
  end

  ---Returns a hash based on the size parameters.
  ---@return string
  function size:hash()
    ---@type string[]
    local items = {
      tostring(self.width),
      tostring(self.height),
      tostring(self.unit),
    }
    return vim.fn.sha256(table.concat(items))
  end

  return size
end

---Move the terminal cursor to cell x, y.
---NOTE: This is relative to the editor, so can be placed outside of normal region.
---@param x integer column position in terminal
---@param y integer row position in terminal
function M.move_cursor(x, y)
  io.stdout:write(string.format(
    '\027[%s;%sH',
    math.floor(y),
    math.floor(x)
  ))
end

---Creates and returns a writer to the raw TTY used by neovim.
---In the case of Windows, this is merely a wrapper for `io.stdout:write()`.
---@return fun(...:string)
function M.new_tty_writer()
  ---Path to the tty used by neovim.
  ---@type file*|nil
  local tty

  ---@param ... string
  return function(...)
    if vim.fn.has('win32') == 1 then
      io.stdout:write(...)
    else
      if not tty then
        local handle = assert(io.popen("tty"))
        local tty_path = assert(handle:read("*l"))
        assert(handle:close())
        tty = assert(io.open(tty_path, 'w'))
      end

      assert(tty:write(...))
      assert(tty:flush())
    end
  end
end

return M
