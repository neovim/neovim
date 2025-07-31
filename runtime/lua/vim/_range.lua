local pos = require('vim._pos')

---@class vim.Range
---@field start vim.Pos Start position.
---@field end_ vim.Pos End position, exclusive.
---@overload fun(start: vim.Pos, end_: vim.Pos): vim.Range
---@overload fun(start_row: integer, start_col: integer, end_row: integer, end_col: integer): vim.Range
local Range = {}
Range.__index = Range

---@package
---@overload fun(start: vim.Pos, end_: vim.Pos): vim.Range
---@overload fun(start_row: integer, start_col: integer, end_row: integer, end_col: integer): vim.Range
function Range:new(...)
  local args = { ... }
  ---@type vim.Pos, vim.Pos
  local start, end_

  if #args == 2 then
    ---@cast args [vim.Pos, vim.Pos]
    start, end_ = unpack(args)
  elseif #args == 4 then
    ---@cast args [integer, integer, integer, integer]
    start, end_ = pos(unpack(args, 1, 2)), pos(unpack(args, 3, 4))
  else
    assert(false)
  end

  ---@class vim.Range
  self = setmetatable({}, self)
  self.start = start
  self.end_ = end_
  return self
end

---@param a vim.Range
---@param b vim.Range
function Range.contains(a, b)
  return a.start <= b.start and a.end_ >= b.end_
end

---@param a vim.Range
---@param b vim.Range
function Range.intercepts(a, b)
  return a.end_ > b.start and a.start < b.end_
end

---@param a vim.Range
---@param b vim.Range
function Range.intersection(a, b)
  if not Range.intercepts(a, b) then
    return nil
  end
  local rs = a.start <= b.start and b or a
  local re = a.end_ >= b.end_ and b or a
  return Range:new(rs.start, re.end_)
end

---@private
---@param a vim.Range
---@param b vim.Range
function Range.__lt(a, b)
  return a.end_ < b.start
end

---@private
---@param a vim.Range
---@param b vim.Range
function Range.__le(a, b)
  return a.end_ <= b.start
end

---@private
---@param a vim.Range
---@param b vim.Range
function Range.__eq(a, b)
  return a.start == b.start and a.end_ == b.end_
end

---@diagnostic disable-next-line: param-type-mismatch
setmetatable(Range, {
  __call = Range.new,
})

return Range
