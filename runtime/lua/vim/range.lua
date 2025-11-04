---@brief
---
--- EXPERIMENTAL: This API may change in the future. Its semantics are not yet finalized.
--- Subscribe to https://github.com/neovim/neovim/issues/25509
--- to stay updated or contribute to its development.
---
--- Provides operations to compare, calculate, and convert ranges represented by |vim.Range|
--- objects.

local validate = vim.validate
local api = vim.api

--- Represents a well-defined range.
---
--- A |vim.Range| object contains a {start} and a {end_} position(see |vim.Pos|).
--- Note that the {end_} position is exclusive.
--- To create a new |vim.Range| object, call `vim.range()`.
---
--- Example:
--- ```lua
--- local pos1 = vim.pos(3, 5)
--- local pos2 = vim.pos(4, 0)
---
--- -- Create a range from two positions.
--- local range1 = vim.range(pos1, pos2)
--- -- Or create a range from four integers representing start and end positions.
--- local range2 = vim.range(3, 5, 4, 0)
---
--- -- Because `vim.Range` is end exclusive, `range1` and `range2` both represent
--- -- a range starting at the row 3, column 5 and ending at where the row 3 ends
--- -- (including the newline at the end of line 3).
---
--- -- Operators are overloaded for comparing two `vim.Pos` objects.
--- if range1 == range2 then
---   print("range1 and range2 are the same range")
--- end
--- ```
---
--- It may include optional fields that enable additional capabilities,
--- such as format conversions. Note that the {start} and {end_} positions
--- need to have the same optional fields.
---
---@class vim.Range
---@field start_row integer 0-based byte index.
---@field start_col integer 0-based byte index.
---@field end_row integer 0-based byte index.
---@field end_col integer 0-based byte index.
---
--- Optional buffer handle.
---
--- When specified, it indicates that this range belongs to a specific buffer.
--- This field is required when performing range conversions.
---@field buf? integer
---@field private [1] integer underlying representation of start_row
---@field private [2] integer underlying representation of start_col
---@field private [3] integer underlying representation of end_row
---@field private [4] integer underlying representation of end_col
local Range = {}

---@private
---@param pos vim.Range
---@param key any
function Range.__index(pos, key)
  if key == 'start_row' then
    return pos[1]
  elseif key == 'start_col' then
    return pos[2]
  elseif key == 'end_row' then
    return pos[3]
  elseif key == 'end_col' then
    return pos[4]
  elseif key == 'buf' then
    return pos[5]
  end

  return Range[key]
end

---@package
---@overload fun(self: vim.Range, start: vim.Pos, end_: vim.Pos): vim.Range
---@overload fun(self: vim.Range, start_row: integer, start_col: integer, end_row: integer, end_col: integer, opts?: vim.Pos.Optional): vim.Range
function Range.new(...)
  ---@type integer, integer, integer, integer, integer|nil
  local start_row, start_col, end_row, end_col, buf

  local nargs = select('#', ...)
  if nargs == 2 then
    ---@type vim.Pos, vim.Pos
    local start, end_ = ...
    validate('start', start, 'table')
    validate('end_', end_, 'table')

    if start.buf ~= end_.buf then
      error('start and end positions must belong to the same buffer')
    end
    start_row, start_col, end_row, end_col, buf =
      start.row, start.col, end_.row, end_.col, start.buf
  elseif nargs == 4 or nargs == 5 then
    local opts
    ---@type integer, integer, integer, integer, vim.Pos.Optional|nil
    start_row, start_col, end_row, end_col, opts = ...
    buf = opts and opts.buf
  else
    error('invalid parameters')
  end

  ---@type vim.Range
  local self = setmetatable({
    start_row,
    start_col,
    end_row,
    end_col,
    buf,
  }, Range)

  return self
end

--- TODO(ofseed): Make it work for unloaded buffers. Check get_line() in vim.lsp.util.
---@param buf integer
---@param row integer
local function get_line(buf, row)
  return api.nvim_buf_get_lines(buf, row, row + 1, true)[1]
end

---@param p1_row integer Row of first position to compare.
---@param p1_col integer Col of first position to compare.
---@param p2_row integer Row of second position to compare.
---@param p2_col integer Col of second position to compare.
---@return integer
--- 1: a > b
--- 0: a == b
--- -1: a < b
local function cmp_pos(p1_row, p1_col, p2_row, p2_col)
  if p1_row == p2_row then
    if p1_col > p2_col then
      return 1
    elseif p1_col < p2_col then
      return -1
    else
      return 0
    end
  elseif p1_row > p2_row then
    return 1
  end

  return -1
end

---@param row integer
---@param col integer
---@param buf integer
---@return integer, integer
local function to_inclusive_pos(row, col, buf)
  if col > 0 then
    col = col - 1
  elseif col == 0 and row > 0 then
    row = row - 1
    col = #get_line(buf, row)
  end

  return row, col
end

---@private
---@param r1 vim.Range
---@param r2 vim.Range
function Range.__lt(r1, r2)
  local r1_inclusive_end_row, r1_inclusive_end_col =
    to_inclusive_pos(r1.end_row, r1.end_col, r1.buf)
  return cmp_pos(r1_inclusive_end_row, r1_inclusive_end_col, r2.start_row, r2.start_col) == -1
end

---@private
---@param r1 vim.Range
---@param r2 vim.Range
function Range.__le(r1, r2)
  local r1_inclusive_end_row, r1_inclusive_end_col =
    to_inclusive_pos(r1.end_row, r1.end_col, r1.buf)
  return cmp_pos(r1_inclusive_end_row, r1_inclusive_end_col, r2.start_row, r2.start_col) ~= 1
end

---@private
---@param r1 vim.Range
---@param r2 vim.Range
function Range.__eq(r1, r2)
  return cmp_pos(r1.start_row, r1.start_col, r2.start_row, r2.start_col) == 0
    and cmp_pos(r1.end_row, r1.end_col, r2.end_row, r2.end_col) == 0
end

--- Checks whether the given range is empty; i.e., start >= end.
---
---@return boolean `true` if the given range is empty
function Range:is_empty()
  local inclusive_end_row, inclusive_end_col =
    to_inclusive_pos(self.end_row, self.end_col, self.buf)

  return cmp_pos(self.start_row, self.start_col, inclusive_end_row, inclusive_end_col) ~= -1
end

--- Checks whether {outer} range contains {inner} range or position.
---
---@param outer vim.Range
---@param inner vim.Range|vim.Pos
---@return boolean `true` if {outer} range fully contains {inner} range or position.
function Range.has(outer, inner)
  if getmetatable(inner) == vim.pos then
    ---@cast inner -vim.Range
    return cmp_pos(outer.start_row, outer.start_col, inner.row, inner.col) ~= 1
      and cmp_pos(outer.end_row, outer.end_col, inner.row, inner.col) ~= -1
  end
  ---@cast inner -vim.Pos

  local outer_inclusive_end_row, outer_inclusive_end_col =
    to_inclusive_pos(outer.end_row, outer.end_col, outer.buf)
  local inner_inclusive_end_row, inner_inclusive_end_col =
    to_inclusive_pos(inner.end_row, inner.end_col, inner.buf)

  return cmp_pos(outer.start_row, outer.start_col, inner.start_row, inner.start_col) ~= 1
    and cmp_pos(outer.end_row, outer.end_col, inner.end_row, inner.end_col) ~= -1
    -- accounts for empty ranges at the start/end of `outer` that per Neovim API and LSP logic
    -- insert the text outside `outer`
    and cmp_pos(outer.start_row, outer.start_col, inner_inclusive_end_row, inner_inclusive_end_col) == -1
    and cmp_pos(
        outer_inclusive_end_row,
        outer_inclusive_end_col,
        inner.start_row,
        inner.start_col
      )
      == 1
end

--- Computes the common range shared by the given ranges.
---
---@param r1 vim.Range First range to intersect.
---@param r2 vim.Range Second range to intersect
---@return vim.Range? range that is present inside both `r1` and `r2`.
---                   `nil` if such range does not exist.
function Range.intersect(r1, r2)
  local r1_inclusive_end_row, r1_inclusive_end_col =
    to_inclusive_pos(r1.end_row, r1.end_col, r1.buf)
  local r2_inclusive_end_row, r2_inclusive_end_col =
    to_inclusive_pos(r2.end_row, r2.end_col, r2.buf)

  if
    cmp_pos(r1_inclusive_end_row, r1_inclusive_end_col, r2.start_row, r2.start_col) ~= 1
    or cmp_pos(r1.start_row, r1.start_col, r2_inclusive_end_row, r2_inclusive_end_col) ~= -1
  then
    return nil
  end

  local rs = cmp_pos(r1.start_row, r1.start_col, r2.start_row, r2.start_col) ~= 1 and r2 or r1
  local re = cmp_pos(r1.end_row, r1.end_col, r2.end_row, r2.end_col) ~= -1 and r2 or r1
  return Range.new(rs.start_row, rs.start_col, re.end_row, re.end_col)
end

--- Converts |vim.Range| to `lsp.Range`.
---
--- Example:
--- ```lua
--- -- `buf` is required for conversion to LSP range.
--- local buf = vim.api.nvim_get_current_buf()
--- local range = vim.range(3, 5, 4, 0, { buf = buf })
---
--- -- Convert to LSP range, you can call it in a method style.
--- local lsp_range = range:to_lsp('utf-16')
--- ```
---@param range vim.Range
---@param position_encoding lsp.PositionEncodingKind
---@return lsp.Range
function Range.to_lsp(range, position_encoding)
  validate('range', range, 'table')
  validate('position_encoding', position_encoding, 'string', true)

  ---@type lsp.Range
  return {
    ['start'] = vim
      .pos(range.start_row, range.start_col, { buf = range.buf })
      :to_lsp(position_encoding),
    ['end'] = vim.pos(range.end_row, range.end_col, { buf = range.buf }):to_lsp(position_encoding),
  }
end

--- Creates a new |vim.Range| from `lsp.Range`.
---
--- Example:
--- ```lua
--- local buf = vim.api.nvim_get_current_buf()
--- local lsp_range = {
---   ['start'] = { line = 3, character = 5 },
---   ['end'] = { line = 4, character = 0 }
--- }
---
--- -- `buf` is mandatory, as LSP ranges are always associated with a buffer.
--- local range = vim.range.lsp(buf, lsp_range, 'utf-16')
--- ```
---@param buf integer
---@param range lsp.Range
---@param position_encoding lsp.PositionEncodingKind
function Range.lsp(buf, range, position_encoding)
  validate('buf', buf, 'number')
  validate('range', range, 'table')
  validate('position_encoding', position_encoding, 'string')

  -- TODO(ofseed): avoid using `Pos:lsp()` here,
  -- as they need reading files separately if buffer is unloaded.
  local start = vim.pos.lsp(buf, range['start'], position_encoding)
  local end_ = vim.pos.lsp(buf, range['end'], position_encoding)

  return Range.new(start, end_)
end

--- Converts |vim.Range| to extmark range (see |api-indexing|).
---
--- Example:
--- ```lua
--- -- `buf` is required for conversion to extmark range.
--- local buf = vim.api.nvim_get_current_buf()
--- local range = vim.range(3, 5, 4, 0, { buf = buf })
---
--- -- Convert to extmark range, you can call it in a method style.
--- local extmark_range = range:to_extmark()
--- ```
---@param range vim.Range
function Range.to_extmark(range)
  validate('range', range, 'table')

  local srow, scol = vim.pos(range.start_row, range.start_col, { buf = range.buf }):to_extmark()
  local erow, ecol = vim.pos(range.end_row, range.end_col, { buf = range.buf }):to_extmark()
  return srow, scol, erow, ecol
end

--- Creates a new |vim.Range| from extmark range (see |api-indexing|).
---
--- Example:
--- ```lua
--- local buf = vim.api.nvim_get_current_buf()
---
--- local range = vim.range.extmark(3, 5, 4, 0, { buf = buf })
--- ```
---@param start_row integer
---@param start_col integer
---@param end_row integer
---@param end_col integer
---@param opts vim.Pos.Optional|nil
function Range.extmark(start_row, start_col, end_row, end_col, opts)
  validate('range', start_row, 'number')
  validate('range', start_col, 'number')
  validate('range', end_row, 'number')
  validate('range', end_col, 'number')

  local start = vim.pos.extmark(start_row, start_col, opts)
  local end_ = vim.pos.extmark(end_row, end_col, opts)

  return Range.new(start, end_)
end

--- Converts |vim.Range| to mark-like range (see |api-indexing|).
---
--- Example:
--- ```lua
--- -- `buf` is required for conversion to extmark range.
--- local buf = vim.api.nvim_get_current_buf()
--- local range = vim.range(3, 5, 4, 0, { buf = buf })
---
--- -- Convert to cursor range, you can call it in a method style.
--- local cursor_range = range:to_cursor()
--- ```
---@param range vim.Range
function Range.to_cursor(range)
  validate('range', range, 'table')

  local srow, scol = vim.pos(range.start_row, range.start_col, { buf = range.buf }):to_cursor()
  local erow, ecol = vim.pos(range.end_row, range.end_col, { buf = range.buf }):to_cursor()
  return srow, scol, erow, ecol
end

--- Creates a new |vim.Range| from mark-like range (see |api-indexing|).
---
--- Example:
--- ```lua
--- local buf = vim.api.nvim_get_current_buf()
--- local start = vim.api.nvim_win_get_cursor(0)
--- -- move the cursor
--- local end_ = vim.api.nvim_win_get_cursor(0)
---
--- local range = vim.range.cursor(start, end_, { buf = buf })
--- ```
---@param buf integer
---@param start_pos [integer, integer]
---@param end_pos [integer, integer]
---@param opts vim.Pos.Optional|nil
function Range.cursor(buf, start_pos, end_pos, opts)
  validate('buf', buf, 'number')
  validate('range', start_pos, 'table')
  validate('range', end_pos, 'table')

  local start = vim.pos.cursor(start_pos, opts)
  local end_ = vim.pos.cursor(end_pos, opts)

  return Range.new(start, end_)
end

-- Overload `Range.new` to allow calling this module as a function.
setmetatable(Range, {
  __call = function(_, ...)
    return Range.new(...)
  end,
})
---@cast Range +fun(start: vim.Pos, end_: vim.Pos): vim.Range
---@cast Range +fun(start_row: integer, start_col: integer, end_row: integer, end_col: integer, opts?: vim.Pos.Optional): vim.Range

return Range
