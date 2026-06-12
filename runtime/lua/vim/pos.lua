---@brief
---
--- EXPERIMENTAL: This API is unstable, do not use it. Its semantics are not yet finalized.
--- Subscribe to this issue to stay updated: https://github.com/neovim/neovim/issues/25509
---
--- Provides operations to compare, calculate, and convert positions represented by |vim.Pos|
--- objects.

local api = vim.api
local validate = vim.validate
local util = require('vim.pos._util')

--- Represents a buffer position based on [api-indexing] (0-indexed, end-exclusive ranges).
--- Call `vim.pos()` to create a new `vim.Pos` by passing the {buf}, {row}, and {col} of a position.
---
--- Example:
--- ```lua
--- local pos1 = vim.pos(0, 3, 5)
--- local pos2 = vim.pos(0, 4, 0)
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
---@field buf integer buffer handle.
---@field private [1] integer underlying representation of row
---@field private [2] integer underlying representation of col
---@field private [3] integer underlying representation of buf
local M = {}

---@private
---@param pos vim.Pos
---@param key any
function M.__index(pos, key)
  if key == 'row' then
    return pos[1]
  elseif key == 'col' then
    return pos[2]
  elseif key == 'buf' then
    return pos[3]
  end

  return M[key]
end

---@package
---@param buf integer
---@param row integer
---@param col integer
function M.new(buf, row, col)
  validate('buf', buf, 'number')
  validate('row', row, 'number')
  validate('col', col, 'number')

  if buf == 0 then
    buf = api.nvim_get_current_buf()
  end

  ---@type vim.Pos
  local self = setmetatable({
    row,
    col,
    buf,
  }, M)

  return self
end

---@private
---@param p1 vim.Pos
---@param p2 vim.Pos
function M.__lt(p1, p2)
  return util.cmp_pos.lt(p1[1], p1[2], p2[1], p2[2])
end

---@private
---@param p1 vim.Pos
---@param p2 vim.Pos
function M.__le(p1, p2)
  return util.cmp_pos.le(p1[1], p1[2], p2[1], p2[2])
end

---@private
---@param p1 vim.Pos
---@param p2 vim.Pos
function M.__eq(p1, p2)
  return util.cmp_pos.eq(p1[1], p1[2], p2[1], p2[2])
end

--- Converts |vim.Pos| to `lsp.Position`.
---
--- Example:
--- ```lua
--- local pos = vim.pos(0, 3, 5)
---
--- -- Convert to LSP position, you can call it in a method style.
--- local lsp_pos = pos:to_lsp('utf-16')
--- ```
---@param pos vim.Pos
---@param position_encoding lsp.PositionEncodingKind
---@return lsp.Position
function M.to_lsp(pos, position_encoding)
  validate('pos', pos, 'table')
  validate('position_encoding', position_encoding, 'string')

  return util.to_lsp(pos.buf, pos[1], pos[2], position_encoding)
end

--- Creates a new |vim.Pos| from `lsp.Position`.
---
--- Example:
--- ```lua
--- local lsp_pos = {
---   line = 3,
---   character = 5
--- }
---
--- local pos = vim.pos.lsp(0, lsp_pos, 'utf-16')
--- ```
---@param buf integer
---@param pos lsp.Position
---@param position_encoding lsp.PositionEncodingKind
---@return vim.Pos
function M.lsp(buf, pos, position_encoding)
  validate('buf', buf, 'number')
  validate('pos', pos, 'table')
  validate('position_encoding', position_encoding, 'string')

  if buf == 0 then
    buf = api.nvim_get_current_buf()
  end

  local row, col = util.from_lsp(buf, pos, position_encoding)
  return M.new(buf, row, col)
end

--- Converts |vim.Pos| to cursor position (see |api-indexing|).
---
--- Example:
--- ```lua
--- local pos = vim.pos(0, 3, 5)
---
--- -- Convert to cursor position, you can call it in a method style.
--- local cursor_pos = { pos:to_cursor() }
--- vim.api.nvim_win_set_cursor(0, cursor_pos)
--- ```
---@param pos vim.Pos
---@return integer lnum, integer col
function M.to_cursor(pos)
  validate('pos', pos, 'table')
  return util.to_mark(pos[1], pos[2])
end

--- Creates a new |vim.Pos| from cursor position (see |api-indexing|).
---
--- Example:
--- ```lua
--- local cursor_pos = vim.api.nvim_win_get_cursor(0)
--- local pos = vim.pos.cursor(0, cursor_pos)
--- ```
---@param buf integer
---@param pos [integer, integer] (lnum, col) tuple
---@return vim.Pos
function M.cursor(buf, pos)
  validate('buf', buf, 'number')
  validate('pos', pos, 'table')

  if buf == 0 then
    buf = api.nvim_get_current_buf()
  end

  return M.new(buf, util.from_mark(pos[1], pos[2]))
end

--- Converts |vim.Pos| to mark position (see |api-indexing|).
---
--- Example:
--- ```lua
--- local pos = vim.pos(0, 3, 5)
---
--- -- Convert to mark position, you can call it in a method style.
--- local lnum, col = pos:to_mark()
--- vim.api.nvim_buf_set_mark(0, 'M', lnum, col, {})
--- ```
---@param pos vim.Pos
---@return integer lnum, integer col
function M.to_mark(pos)
  validate('pos', pos, 'table')
  return util.to_mark(pos[1], pos[2])
end

--- Creates a new |vim.Pos| from mark position (see |api-indexing|).
---
--- Example:
--- ```lua
--- local mark_info = vim.api.nvim_get_mark('M', {})
--- local lnum, col, buf, name = unpack(mark_info)
---
--- if lnum == 0 and col == 0 and buf == 0 then
---   return -- mark 'M' is not set.
--- end
---
--- local pos = vim.pos.mark(buf, lnum, col)
--- ```
---@param buf integer
---@param lnum integer
---@param col integer
---@return vim.Pos
function M.mark(buf, lnum, col)
  validate('buf', buf, 'number')
  validate('lnum', lnum, 'number')
  validate('col', col, 'number')

  if buf == 0 then
    buf = api.nvim_get_current_buf()
  end

  return M.new(buf, util.from_mark(lnum, col))
end

--- Converts |vim.Pos| to extmark position (see |api-indexing|).
---
--- Example:
--- ```lua
--- local pos = vim.pos(0, 3, 5)
---
--- -- Convert to extmark position, you can call it in a method style.
--- local extmark_pos = pos:to_extmark()
--- ```
---@param pos vim.Pos
---@return integer row, integer col
function M.to_extmark(pos)
  validate('pos', pos, 'table')
  return pos[1], pos[2]
end

--- Creates a new |vim.Pos| from extmark position (see |api-indexing|).
---
--- Example:
--- ```lua
--- local pos = vim.pos.extmark(0, 3, 5)
--- ```
---@param buf integer
---@param row integer
---@param col integer
---@return vim.Pos
function M.extmark(buf, row, col)
  validate('buf', buf, 'number')
  validate('row', row, 'number')
  validate('col', col, 'number')

  if buf == 0 then
    buf = api.nvim_get_current_buf()
  end

  return M.new(buf, row, col)
end

--- Converts |vim.Pos| to buffer (bytes) offset.
---
--- Example:
--- ```lua
--- local p1 = vim.pos(0, 3, 5)
--- local p2 = vim.pos(0, 4, 0)
---
--- -- Convert to buffer offset, you can call it in a method style.
--- local offset1 = p1:to_offset()
--- local offset2 = p2:to_offset()
--- -- Can be used to calculate the distance between two locations.
--- local distance = offset2 - offset1
--- ```
---@param pos vim.Pos
---@return integer
function M.to_offset(pos)
  validate('pos', pos, 'table')
  return api.nvim_buf_get_offset(pos.buf, pos[1]) + pos[2]
end

--- Creates a new |vim.Pos| from buffer (bytes) offset.
---
--- Example:
--- ```lua
--- local offset = vim.api.nvim_buf_get_offset(0, vim.api.nvim_buf_line_count(0))
--- local pos = vim.pos.offset(0, offset)
--- ```
---@param buf integer
---@param offset integer
---@return vim.Pos
function M.offset(buf, offset)
  validate('buf', buf, 'number')
  validate('offset', offset, 'number')

  local lnum = vim.list.bisect(
    setmetatable({}, {
      __index = function(_, lnum)
        return api.nvim_buf_get_offset(buf, lnum - 1)
      end,
    }),
    offset,
    { lo = 1, hi = api.nvim_buf_line_count(buf) + 2, bound = 'upper' }
  ) - 1

  local row = lnum - 1
  local col = offset - api.nvim_buf_get_offset(buf, row)
  return M.new(buf, row, col)
end

-- Overload `Range.new` to allow calling this module as a function.
setmetatable(M, {
  __call = function(_, ...)
    return M.new(...)
  end,
})
---@cast M +fun(buf: integer, row: integer, col: integer): vim.Pos

return M
