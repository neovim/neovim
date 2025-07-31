---@class vim.Pos
---@field row integer 0-based byte index.
---@field col integer 0-based byte index.
---@overload fun(row: integer, col: integer): vim.Pos
local Pos = {}
Pos.__index = Pos

---@package
---@param row integer
---@param col integer
function Pos:new(row, col)
  ---@class vim.Pos
  self = setmetatable({}, self)
  self.row = row
  self.col = col
  return self
end

---@param a vim.Pos
---@param b vim.Pos
---@return integer
--- 1: a > b
--- 0: a == b
--- -1: a < b
local function cmp_pos(a, b)
  if a.row == b.row then
    if a.col > b.col then
      return 1
    elseif a.col < b.col then
      return -1
    else
      return 0
    end
  elseif a.row > b.row then
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

---@diagnostic disable-next-line: param-type-mismatch
setmetatable(Pos, {
  __call = Pos.new,
})

return Pos
