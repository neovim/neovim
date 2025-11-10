---@brief
---
--- EXPERIMENTAL: This API may change in the future. Its semantics are not yet finalized.
--- Subscribe to https://github.com/neovim/neovim/issues/25509
--- to stay updated or contribute to its development.
---
--- Provides operations to compare, calculate, and convert ranges represented by |vim.Range|
--- objects.

local validate = vim.validate

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
--- -- a range starting at the row 3, column 5 and ending at where the row 3 ends.
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
---@field start vim.Pos Start position.
---@field end_ vim.Pos End position, exclusive.
local Range = {}
Range.__index = Range

---@package
---@overload fun(self: vim.Range, start: vim.Pos, end_: vim.Pos): vim.Range
---@overload fun(self: vim.Range, start_row: integer, start_col: integer, end_row: integer, end_col: integer, opts?: vim.Pos.Optional): vim.Range
function Range.new(...)
  ---@type vim.Pos, vim.Pos, vim.Pos.Optional
  local start, end_

  local nargs = select('#', ...)
  if nargs == 2 then
    ---@type vim.Pos, vim.Pos
    start, end_ = ...
    validate('start', start, 'table')
    validate('end_', end_, 'table')

    if start.buf ~= end_.buf then
      error('start and end positions must belong to the same buffer')
    end
  elseif nargs == 4 or nargs == 5 then
    ---@type integer, integer, integer, integer, vim.Pos.Optional
    local start_row, start_col, end_row, end_col, opts = ...
    start, end_ = vim.pos(start_row, start_col, opts), vim.pos(end_row, end_col, opts)
  else
    error('invalid parameters')
  end

  ---@type vim.Range
  local self = setmetatable({
    start = start,
    end_ = end_,
  }, Range)

  return self
end

---@private
---@param r1 vim.Range
---@param r2 vim.Range
function Range.__lt(r1, r2)
  return r1.end_ < r2.start
end

---@private
---@param r1 vim.Range
---@param r2 vim.Range
function Range.__le(r1, r2)
  return r1.end_ <= r2.start
end

---@private
---@param r1 vim.Range
---@param r2 vim.Range
function Range.__eq(r1, r2)
  return r1.start == r2.start and r1.end_ == r2.end_
end

--- Checks whether the given range is empty; i.e., start >= end.
---
---@return boolean `true` if the given range is empty
function Range:is_empty()
  return self.start >= self.end_
end

--- Checks whether {outer} range contains {inner} range.
---
---@param outer vim.Range
---@param inner vim.Range
---@return boolean `true` if {outer} range fully contains {inner} range.
function Range.has(outer, inner)
  return outer.start <= inner.start and outer.end_ >= inner.end_
end

--- Computes the common range shared by the given ranges.
---
---@param r1 vim.Range First range to intersect.
---@param r2 vim.Range Second range to intersect
---@return vim.Range? range that is present inside both `r1` and `r2`.
---                   `nil` if such range does not exist.
function Range.intersect(r1, r2)
  if r1.end_ <= r2.start or r1.start >= r2.end_ then
    return nil
  end
  local rs = r1.start <= r2.start and r2 or r1
  local re = r1.end_ >= r2.end_ and r2 or r1
  return Range.new(rs.start, re.end_)
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
function Range.to_lsp(range, position_encoding)
  validate('range', range, 'table')
  validate('position_encoding', position_encoding, 'string', true)

  ---@type lsp.Range
  return {
    ['start'] = range.start:to_lsp(position_encoding),
    ['end'] = range.end_:to_lsp(position_encoding),
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

-- Overload `Range.new` to allow calling this module as a function.
setmetatable(Range, {
  __call = function(_, ...)
    return Range.new(...)
  end,
})
---@cast Range +fun(start: vim.Pos, end_: vim.Pos): vim.Range
---@cast Range +fun(start_row: integer, start_col: integer, end_row: integer, end_col: integer, opts?: vim.Pos.Optional): vim.Range

return Range
