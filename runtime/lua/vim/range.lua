---@brief
---
--- EXPERIMENTAL: This API is unstable, do not use it. Its semantics are not yet finalized.
--- Subscribe to this issue to stay updated: https://github.com/neovim/neovim/issues/25509
---
--- Provides operations to compare, calculate, and convert ranges represented by |vim.Range|
--- objects.

local validate = vim.validate
local api = vim.api
local util = require('vim.pos._util')

--- Represents a range based on [api-indexing] (0-indexed, end-exclusive). Call `vim.range()` to
--- create a new range by passing start and end positions (|vim.Pos|).
---
--- Both positions must have the same optional fields, which may enable additional capabilities
--- (such as format conversions).
---
--- Example:
--- ```lua
--- local pos1 = vim.pos(0, 3, 5)
--- local pos2 = vim.pos(0, 4, 0)
---
--- -- Create a range from two positions.
--- local range1 = vim.range(pos1, pos2)
--- -- Or create a range from four integers representing start and end positions.
--- local range2 = vim.range(0, 3, 5, 4, 0)
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
---@class vim.Range
---@field start_row integer 0-based byte index.
---@field start_col integer 0-based byte index.
---@field end_row integer 0-based byte index.
---@field end_col integer 0-based byte index.
---@field buf integer Optional buffer handle.
---@field private [1] integer underlying representation of start_row
---@field private [2] integer underlying representation of start_col
---@field private [3] integer underlying representation of end_row
---@field private [4] integer underlying representation of end_col
---@field private [5] integer underlying representation of buf
local M = {}

---@private
---@param pos vim.Range
---@param key any
function M.__index(pos, key)
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

  return M[key]
end

---@package
---@overload fun(start: vim.Pos, end_: vim.Pos): vim.Range
---@overload fun(buf: integer, start_row: integer, start_col: integer, end_row: integer, end_col: integer): vim.Range
function M.new(...)
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
    start_row, start_col, end_row, end_col, buf = start[1], start[2], end_[1], end_[2], start.buf
  elseif nargs == 5 then
    ---@type integer, integer, integer, integer, integer
    buf, start_row, start_col, end_row, end_col = ...
    validate('buf', buf, 'number')
    validate('start_row', start_row, 'number')
    validate('start_col', start_col, 'number')
    validate('end_row', end_row, 'number')
    validate('end_col', end_col, 'number')
  else
    error('invalid parameters')
  end

  if buf == 0 then
    buf = api.nvim_get_current_buf()
  end

  ---@type vim.Range
  local self = setmetatable({
    start_row,
    start_col,
    end_row,
    end_col,
    buf,
  }, M)

  return self
end

---@param row integer
---@param col integer
---@param buf integer
---@return integer, integer
local function to_inclusive_pos(buf, row, col)
  local line = util.get_line(buf, row)
  if col > 0 then
    col = col + vim.str_utf_start(line, col) - 1
  elseif col == 0 and row > 0 then
    row = row - 1
    col = #line > 0 and #line + vim.str_utf_start(line, #line) - 1 or 0
  end

  return row, col
end

---@param row integer
---@param col integer
---@param buf integer
---@return integer, integer
local function to_exclusive_pos(buf, row, col)
  local line = util.get_line(buf, row)
  if col >= #line then
    row = row + 1
    col = 0
  else
    col = col + vim.str_utf_end(line, col + 1) + 1
  end

  return row, col
end

---@private
---@param r1 vim.Range
---@param r2 vim.Range
function M.__lt(r1, r2)
  if r1:is_empty() or r2:is_empty() then
    return util.cmp_pos.le(r1[3], r1[4], r2[1], r2[2])
  end

  local r1_inclusive_end_row, r1_inclusive_end_col = to_inclusive_pos(r1.buf, r1[3], r1[4])
  return util.cmp_pos.lt(r1_inclusive_end_row, r1_inclusive_end_col, r2[1], r2[2])
end

---@private
---@param r1 vim.Range
---@param r2 vim.Range
function M.__le(r1, r2)
  if r1:is_empty() or r2:is_empty() then
    return util.cmp_pos.le(r1[3], r1[4], r2[1], r2[2])
  end

  local r1_inclusive_end_row, r1_inclusive_end_col = to_inclusive_pos(r1.buf, r1[3], r1[4])
  return util.cmp_pos.le(r1_inclusive_end_row, r1_inclusive_end_col, r2[1], r2[2])
end

---@private
---@param r1 vim.Range
---@param r2 vim.Range
function M.__eq(r1, r2)
  return util.cmp_pos.eq(r1[1], r1[2], r2[1], r2[2]) and util.cmp_pos.eq(r1[3], r1[4], r2[3], r2[4])
end

--- Checks whether the given range is empty; i.e., start >= end.
---
---@param range vim.Range
---@return boolean `true` if the given range is empty.
function M.is_empty(range)
  validate('range', range, 'table')
  return util.cmp_pos.ge(range[1], range[2], range[3], range[4])
end

--- Checks whether {outer} range contains {inner} range or position.
---
---@param outer vim.Range
---@param inner vim.Range|vim.Pos
---@return boolean `true` if {outer} range fully contains {inner} range or position.
function M.has(outer, inner)
  validate('outer', outer, 'table')
  validate('inner', inner, 'table')

  if getmetatable(inner) == vim.pos then
    ---@cast inner -vim.Range
    return util.cmp_pos.le(outer[1], outer[2], inner[1], inner[2])
      and util.cmp_pos.ge(outer[3], outer[4], inner[1], inner[2])
  end
  ---@cast inner -vim.Pos

  if outer:is_empty() then
    return false
  end

  -- accounts for empty ranges at the start/end of `outer` that per Neovim API and LSP logic insert
  -- the text outside `outer`
  if
    (
      util.cmp_pos.ge(outer[1], outer[2], inner[3], inner[4])
      or util.cmp_pos.le(outer[3], outer[4], inner[1], inner[2])
    ) and inner:is_empty()
  then
    return false
  end

  return util.cmp_pos.le(outer[1], outer[2], inner[1], inner[2])
    and util.cmp_pos.ge(outer[3], outer[4], inner[3], inner[4])
end

--- Computes the common range shared by the given ranges.
---
---@param r1 vim.Range First range to intersect.
---@param r2 vim.Range Second range to intersect
---@return vim.Range? range that is present inside both `r1` and `r2`.
---                   `nil` if such range does not exist.
function M.intersect(r1, r2)
  validate('r1', r1, 'table')
  validate('r2', r2, 'table')

  if r1.buf ~= r2.buf then
    return nil
  end
  if r1:is_empty() or r2:is_empty() then
    return nil
  end

  local r1_inclusive_end_row, r1_inclusive_end_col = to_inclusive_pos(r1.buf, r1[3], r1[4])
  local r2_inclusive_end_row, r2_inclusive_end_col = to_inclusive_pos(r2.buf, r2[3], r2[4])

  if
    util.cmp_pos.le(r1_inclusive_end_row, r1_inclusive_end_col, r2[1], r2[2])
    or util.cmp_pos.ge(r1[1], r1[2], r2_inclusive_end_row, r2_inclusive_end_col)
  then
    return nil
  end

  local rs = util.cmp_pos.le(r1[1], r1[2], r2[1], r2[2]) and r2 or r1
  local re = util.cmp_pos.ge(r1[3], r1[4], r2[3], r2[4]) and r2 or r1
  return M.new(r1.buf, rs[1], rs[2], re[3], re[4])
end

--- Converts |vim.Range| to `lsp.Range`.
---
--- Example:
--- ```lua
--- local range = vim.range(0, 3, 5, 4, 0)
---
--- -- Convert to LSP range, you can call it in a method style.
--- local lsp_range = range:to_lsp('utf-16')
--- ```
---@param range vim.Range
---@param position_encoding lsp.PositionEncodingKind
---@return lsp.Range
function M.to_lsp(range, position_encoding)
  validate('range', range, 'table')
  validate('position_encoding', position_encoding, 'string', true)

  local buf = range.buf
  ---@type lsp.Range
  return {
    ['start'] = util.to_lsp(buf, range[1], range[2], position_encoding),
    ['end'] = util.to_lsp(buf, range[3], range[4], position_encoding),
  }
end

--- Creates a new |vim.Range| from `lsp.Range`.
---
--- Example:
--- ```lua
--- local lsp_range = {
---   ['start'] = { line = 3, character = 5 },
---   ['end'] = { line = 4, character = 0 }
--- }
---
--- local range = vim.range.lsp(0, lsp_range, 'utf-16')
--- ```
---@param buf integer
---@param range lsp.Range
---@param position_encoding lsp.PositionEncodingKind
---@return vim.Range
function M.lsp(buf, range, position_encoding)
  validate('buf', buf, 'number')
  validate('range', range, 'table')
  validate('position_encoding', position_encoding, 'string')

  if buf == 0 then
    buf = api.nvim_get_current_buf()
  end

  local start_row, start_col = util.from_lsp(buf, range['start'], position_encoding)
  local end_row, end_col = util.from_lsp(buf, range['end'], position_encoding)
  return M.new(buf, start_row, start_col, end_row, end_col)
end

--- Converts |vim.Range| to extmark range (see |api-indexing|).
---
--- Example:
--- ```lua
--- local range = vim.range(0, 3, 5, 4, 0)
---
--- -- Convert to mark range, you can call it in a method style.
--- local start_lnum, start_col, end_lnum, end_col = range:to_mark()
--- ```
---@param range vim.Range
---@return integer start_lnum, integer start_col, integer end_lnum, integer end_col
function M.to_mark(range)
  validate('range', range, 'table')

  local buf = range.buf
  local start_row, start_col, end_row, end_col = range[1], range[2], range[3], range[4]
  if vim.o.selection ~= 'exclusive' then
    end_row, end_col = to_inclusive_pos(buf, end_row, end_col)
  end

  start_row, start_col = util.to_mark(start_row, start_col)
  end_row, end_col = util.to_mark(end_row, end_col)
  return start_row, start_col, end_row, end_col
end

--- Creates a new |vim.Range| from "mark-indexed" range (see |api-indexing|).
---
--- Example:
--- ```lua
--- -- A range represented by marks may be end-inclusive (decided by 'selection' option).
--- local start_lnum, start_col = unpack(api.nvim_buf_get_mark(bufnr, '<'))
--- local end_lnum, end_col = unpack(api.nvim_buf_get_mark(bufnr, '>'))
---
--- -- Create an end-exclusive range.
--- local range = vim.range.mark(0, start_lnum, start_col, end_lnum, end_col)
--- ```
---@param buf integer
---@param start_lnum integer
---@param start_col integer
---@param end_lnum integer
---@param end_col integer
---@return vim.Range
function M.mark(buf, start_lnum, start_col, end_lnum, end_col)
  validate('buf', buf, 'number')
  validate('start_lnum', start_lnum, 'number')
  validate('start_col', start_col, 'number')
  validate('end_lnum', end_lnum, 'number')
  validate('end_col', end_col, 'number')

  if buf == 0 then
    buf = api.nvim_get_current_buf()
  end

  start_lnum, start_col = util.from_mark(start_lnum, start_col)
  end_lnum, end_col = util.from_mark(end_lnum, end_col)

  if vim.o.selection ~= 'exclusive' then
    end_lnum, end_col = to_exclusive_pos(buf, end_lnum, end_col)
  end
  return M.new(buf, start_lnum, start_col, end_lnum, end_col)
end

--- Converts |vim.Range| to extmark range (see |api-indexing|).
---
--- Example:
--- ```lua
--- local range = vim.range(0, 3, 5, 4, 0)
---
--- -- Convert to extmark range, you can call it in a method style.
--- local extmark_range = range:to_extmark()
--- ```
---@param range vim.Range
---@return integer start_row, integer start_col, integer end_row, integer end_col
function M.to_extmark(range)
  validate('range', range, 'table')

  local buf = range.buf
  local start_row, start_col, end_row, end_col = range[1], range[2], range[3], range[4]
  -- Consider a buffer like this:
  -- ```
  -- 0123456
  -- abcdefg
  -- ```
  --
  -- Two ways to describe the range of the first line, i.e. '0123456':
  -- 1. `{ start_row = 0, start_col = 0, end_row = 0, end_col = 7 }`
  -- 2. `{ start_row = 0, start_col = 0, end_row = 1, end_col = 0 }`
  --
  -- Both of the above methods satisfy the "end-exclusive" definition,
  -- but `nvim_buf_set_extmark()` throws an out-of-bounds error for the second method,
  -- so we need to convert it to the first method.
  if end_col == 0 and end_row == api.nvim_buf_line_count(buf) then
    end_row = end_row - 1
    end_col = #util.get_line(buf, end_row)
  end
  return start_row, start_col, end_row, end_col
end

--- Creates a new |vim.Range| from extmark range (see |api-indexing|).
---
--- Example:
--- ```lua
--- local range = vim.range.extmark(0, 3, 5, 4, 0)
--- ```
---@param buf integer
---@param start_row integer
---@param start_col integer
---@param end_row integer
---@param end_col integer
---@return vim.Range
function M.extmark(buf, start_row, start_col, end_row, end_col)
  validate('buf', buf, 'number')
  validate('start_row', start_row, 'number')
  validate('start_col', start_col, 'number')
  validate('end_row', end_row, 'number')
  validate('end_col', end_col, 'number')

  if buf == 0 then
    buf = api.nvim_get_current_buf()
  end

  return M.new(buf, start_row, start_col, end_row, end_col)
end

-- Overload `Range.new` to allow calling this module as a function.
setmetatable(M, {
  __call = function(_, ...)
    return M.new(...)
  end,
})
---@cast M +fun(start: vim.Pos, end_: vim.Pos): vim.Range
---@cast M +fun(buf: integer, start_row: integer, start_col: integer, end_row: integer, end_col: integer): vim.Range

return M
