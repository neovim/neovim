---@brief
---
--- EXPERIMENTAL: This API is unstable, do not use it. Its semantics are not yet finalized.
--- Subscribe to this issue to stay updated: https://github.com/neovim/neovim/issues/25509
---
--- Provides operations to compare, calculate, and convert positions represented by |vim.Pos|
--- objects.

local M = {}

local api = vim.api
local validate = vim.validate

--- Represents a well-defined position.
---
--- A |vim.Pos| object contains the {row} and {col} coordinates of a position.
--- To create a new |vim.Pos| object, call `vim.pos()`.
---
--- Example:
--- ```lua
--- local pos1 = vim.pos(vim.api.nvim_get_current_buf(), 3, 5)
--- local pos2 = vim.pos(vim.api.nvim_get_current_buf(), 4, 0)
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
local Pos = {}

M._Pos = Pos

---@param pos vim.Pos
---@param key any
function Pos.__index(pos, key)
  if key == 'row' then
    return pos[1]
  elseif key == 'col' then
    return pos[2]
  elseif key == 'buf' then
    return pos[3]
  end

  return Pos[key]
end

---@package
---@param buf integer
---@param row integer
---@param col integer
function Pos.new(buf, row, col)
  validate('buf', buf, 'number')
  validate('row', row, 'number')
  validate('col', col, 'number')

  ---@type vim.Pos
  local self = setmetatable({
    row,
    col,
    buf,
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

function Pos.__lt(...)
  return cmp_pos(...) == -1
end

function Pos.__le(...)
  return cmp_pos(...) ~= 1
end

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
--- local buf = vim.api.nvim_get_current_buf()
--- local pos = vim.pos(buf, 3, 5)
---
--- -- Convert to LSP position, you can call it in a method style.
--- local lsp_pos = pos:to_lsp('utf-16')
--- ```
---@param position_encoding lsp.PositionEncodingKind
function Pos:to_lsp(position_encoding)
  validate('position_encoding', position_encoding, 'string')

  local buf, row, col = self.buf, self.row, self.col
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
--- local pos = vim.pos.lsp(buf, lsp_pos, 'utf-16')
--- ```
---@param buf integer
---@param pos lsp.Position
---@param position_encoding lsp.PositionEncodingKind
---@return vim.Pos
function M.lsp(buf, pos, position_encoding)
  validate('buf', buf, 'number')
  validate('pos', pos, 'table')
  validate('position_encoding', position_encoding, 'string')

  local row, col = pos.line, pos.character
  -- When on the first character,
  -- we can ignore the difference between byte and character.
  if col > 0 then
    -- `strict_indexing` is disabled, because LSP responses are asynchronous,
    -- and the buffer content may have changed, causing out-of-bounds errors.
    col = vim.str_byteindex(get_line(buf, row), position_encoding, col, false)
  end

  return Pos.new(buf, row, col)
end

--- Converts |vim.Pos| to cursor position (see |api-indexing|).
---@return integer, integer
function Pos:to_cursor()
  return self.row + 1, self.col
end

--- Creates a new |vim.Pos| from cursor position (see |api-indexing|).
---@param buf integer
---@param pos [integer, integer]
---@return vim.Pos
function M.cursor(buf, pos)
  return Pos.new(buf, pos[1] - 1, pos[2])
end

--- Converts |vim.Pos| to extmark position (see |api-indexing|).
---@return integer, integer
function Pos:to_extmark()
  local line_num = #api.nvim_buf_get_lines(self.buf, 0, -1, true)

  local row = self.row
  local col = self.col
  if self.col == 0 and self.row == line_num then
    row = row - 1
    col = #get_line(self.buf, row)
  end

  return row, col
end

--- Creates a new |vim.Pos| from extmark position (see |api-indexing|).
---@param buf integer
---@param row integer
---@param col integer
---@return vim.Pos
function M.extmark(buf, row, col)
  return Pos.new(buf, row, col)
end

setmetatable(M, {
  __call = function(_, ...)
    return Pos.new(...)
  end,
})
---@cast M +fun(buf: integer, row: integer, col: integer): vim.Pos

return M
