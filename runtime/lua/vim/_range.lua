local validate = vim.validate
local pos = require('vim._pos')

---@class vim.Range
---@field start vim.Pos Start position.
---@field end_ vim.Pos End position, exclusive.
---@overload fun(start: vim.Pos, end_: vim.Pos): vim.Range
---@overload fun(start_row: integer, start_col: integer, end_row: integer, end_col: integer, opts?: vim.Pos.Optional): vim.Range
local Range = {}
Range.__index = Range

---@package
---@overload fun(self: vim.Range, start: vim.Pos, end_: vim.Pos): vim.Range
---@overload fun(self: vim.Range, start_row: integer, start_col: integer, end_row: integer, end_col: integer, opts?: vim.Pos.Optional): vim.Range
function Range:new(...)
  ---@type vim.Pos, vim.Pos, vim.pos.new.Opts
  local start, end_

  local args = { ... }
  if #args == 2 then
    ---@cast args [vim.Pos, vim.Pos]
    start, end_ = unpack(args)
    validate('start', start, 'table')
    validate('end_', end_, 'table')
  elseif #args == 4 or #args == 5 then
    ---@cast args [integer, integer, integer, integer, vim.Pos.Optional?]
    start, end_ = pos(args[1], args[2], args[5]), pos(args[3], args[4], args[5])
  else
    error('invalid parameters')
  end

  ---@class vim.Range
  self = setmetatable({}, self)
  self.start = start
  self.end_ = end_
  return self
end

---@param range vim.Range
---@param position_encoding lsp.PositionEncodingKind
local function to_lsp_range(range, position_encoding)
  ---@type lsp.Range
  return {
    ['start'] = range.start:lsp(position_encoding),
    ['end'] = range.end_:lsp(position_encoding),
  }
end

---@param bufnr integer
---@param range lsp.Range
---@param position_encoding lsp.PositionEncodingKind
local function from_lsp_range(bufnr, range, position_encoding)
  -- TODO(ofseed): avoid using `Pos:lsp()` here,
  -- as they need reading files separately if buffer is unloaded.
  local start = pos.lsp(bufnr, range['start'], position_encoding)
  local end_ = pos.lsp(bufnr, range['end'], position_encoding)
  return Range:new(start, end_)
end

---@overload fun(range: vim.Pos, position_encoding: lsp.PositionEncodingKind): lsp.Range
---@overload fun(bufnr: integer, range: lsp.Position, position_encoding: lsp.PositionEncodingKind): vim.Range
function Range.lsp(...)
  local args = { ... }
  if #args == 2 then
    return to_lsp_range(...)
  elseif #args == 3 then
    return from_lsp_range(...)
  else
    error('invalid parameters')
  end
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
  return Range:new(rs.start, re.end_)
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

---@diagnostic disable-next-line: param-type-mismatch
setmetatable(Range, {
  __call = Range.new,
})

return Range
