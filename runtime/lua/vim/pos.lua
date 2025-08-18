---@brief
---
--- WARNING: This module is under experimental support.
--- Its semantics are not yet finalized,
--- and the stability of this API is not guaranteed.
--- Avoid using it outside of Nvim.
--- You may subscribe to or participate in the tracking issue
--- https://github.com/neovim/neovim/issues/25509
--- to stay updated or contribute to its development.
---
--- Built on |vim.Pos| objects, this module offers operations
--- that support comparisons and conversions between various types of positions.

local api = vim.api
local validate = vim.validate

--- Represents a well-defined position.
---
--- A |vim.Pos| object contains the {row} and {col} coordinates of a position.
--- To create a new |vim.Pos| object, call `vim.pos()`.
---
--- Example:
--- ```lua
--- local pos1 = vim.pos(3, 5)
--- local pos2 = vim.pos(4, 0)
---
--- -- Operators are overloaded for comparing two `vim.Pos` objects.
--- if pos1 < pos2 then
---   print("pos1 comes before pos2")
--- end
---
--- if pos1 ~= pos2 then
---   print("pos1 and pos2 are different positions")
--- end
--- ```
---
--- It may include optional fields that enable additional capabilities,
--- such as format conversions.
---
---@class vim.Pos
---@field row integer 0-based byte index.
---@field col integer 0-based byte index.
---
--- Optional buffer handle.
---
--- When specified, it indicates that this position belongs to a specific buffer.
--- This field is required when performing position conversions.
---@field buf? integer
local Pos = {}
Pos.__index = Pos

---@class vim.Pos.Optional
---@inlinedoc
---@field buf? integer

---@package
---@param row integer
---@param col integer
---@param opts? vim.Pos.Optional
function Pos.new(row, col, opts)
  validate('row', row, 'number')
  validate('col', col, 'number')
  validate('opts', opts, 'table', true)

  opts = opts or {}

  ---@type vim.Pos
  local self = setmetatable({
    row = row,
    col = col,
    buf = opts.buf,
  }, Pos)

  return self
end

---@param p1 vim.Pos First position to compare.
---@param p2 vim.Pos Second position to compare.
---@return integer
--- 1: a > b
--- 0: a == b
--- -1: a < b
local function cmp_pos(p1, p2)
  if p1.row == p2.row then
    if p1.col > p2.col then
      return 1
    elseif p1.col < p2.col then
      return -1
    else
      return 0
    end
  elseif p1.row > p2.row then
    return 1
  end

  return -1
end

---@private
function Pos.__lt(...)
  return cmp_pos(...) == -1
end

---@private
function Pos.__le(...)
  return cmp_pos(...) ~= 1
end

---@private
function Pos.__eq(...)
  return cmp_pos(...) == 0
end

--- TODO(ofseed): Make it work for unloaded buffers. Check get_line() in vim.lsp.util.
---@param buf integer
---@param row integer
local function get_line(buf, row)
  return api.nvim_buf_get_lines(buf, row, row + 1, true)[1]
end

--- Converts |vim.Pos| to `lsp.Position`.
---
--- Example:
--- ```lua
--- -- `buf` is required for conversion to LSP position.
--- local buf = vim.api.nvim_get_current_buf()
--- local pos = vim.pos(3, 5, { buf = buf })
---
--- -- Convert to LSP position, you can call it in a method style.
--- local lsp_pos = pos:lsp('utf-16')
--- ```
---@param pos vim.Pos
---@param position_encoding lsp.PositionEncodingKind
function Pos.to_lsp(pos, position_encoding)
  validate('pos', pos, 'table')
  validate('position_encoding', position_encoding, 'string')

  local buf = assert(pos.buf, 'position is not a buffer position')
  local row, col = pos.row, pos.col
  -- When on the first character,
  -- we can ignore the difference between byte and character.
  if col > 0 then
    col = vim.str_utfindex(get_line(buf, row), position_encoding, col, false)
  end

  ---@type lsp.Position
  return { line = row, character = col }
end

--- Creates a new |vim.Pos| from `lsp.Position`.
---
--- Example:
--- ```lua
--- local buf = vim.api.nvim_get_current_buf()
--- local lsp_pos = {
---   line = 3,
---   character = 5
--- }
---
--- -- `buf` is mandatory, as LSP positions are always associated with a buffer.
--- local pos = vim.pos.lsp(buf, lsp_pos, 'utf-16')
--- ```
---@param buf integer
---@param pos lsp.Position
---@param position_encoding lsp.PositionEncodingKind
function Pos.lsp(buf, pos, position_encoding)
  validate('buf', buf, 'number')
  validate('pos', pos, 'table')
  validate('position_encoding', position_encoding, 'string')

  local row, col = pos.line, pos.character
  -- When on the first character,
  -- we can ignore the difference between byte and character.
  if col > 0 then
    col = vim.str_byteindex(get_line(buf, row), position_encoding, col)
  end

  return Pos.new(row, col, { buf = buf })
end

-- Overload `Range.new` to allow calling this module as a function.
setmetatable(Pos, {
  __call = function(_, ...)
    return Pos.new(...)
  end,
})
---@cast Pos +fun(row: integer, col: integer, opts: vim.Pos.Optional?): vim.Pos

return Pos
