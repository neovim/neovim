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

--- Represents a well-defined position.
---
--- A |vim.Pos| object contains the {row} and {col} coordinates of a position.
--- To create a new |vim.Pos| object, call `vim.pos()`.
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
---@return integer, integer
function M.to_cursor(pos)
  return util.to_mark(pos[1], pos[2])
end

--- Creates a new |vim.Pos| from cursor position (see |api-indexing|).
---@param buf integer
---@param pos [integer, integer]
function M.cursor(buf, pos)
  return M.new(buf, util.from_mark(pos[1], pos[2]))
end

--- Converts |vim.Pos| to mark position (see |api-indexing|).
---@param pos vim.Pos
---@return integer, integer
function M.to_mark(pos)
  return util.to_mark(pos[1], pos[2])
end

--- Creates a new |vim.Pos| from mark position (see |api-indexing|).
---@param buf integer
---@param row integer
---@param col integer
function M.mark(buf, row, col)
  if buf == 0 then
    buf = api.nvim_get_current_buf()
  end

  return M.new(buf, util.from_mark(row, col))
end

--- Converts |vim.Pos| to extmark position (see |api-indexing|).
---@param pos vim.Pos
---@return integer, integer
function M.to_extmark(pos)
  return pos[1], pos[2]
end

--- Creates a new |vim.Pos| from extmark position (see |api-indexing|).
---@param buf integer
---@param row integer
---@param col integer
function M.extmark(buf, row, col)
  if buf == 0 then
    buf = api.nvim_get_current_buf()
  end

  return M.new(buf, row, col)
end

--- Converts |vim.Pos| to buffer offset.
---@param pos vim.Pos
---@return integer
function M.to_offset(pos)
  return api.nvim_buf_get_offset(pos.buf, pos[1]) + pos[2]
end

--- Creates a new |vim.Pos| from buffer offset.
---@param buf integer
---@param offset integer
---@return vim.Pos
function M.offset(buf, offset)
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
