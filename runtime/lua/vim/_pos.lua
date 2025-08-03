local api = vim.api
local validate = vim.validate

---@class vim.Pos.Optional
---@inlinedoc
---@field bufnr? integer

---@class vim.Pos : vim.Pos.Optional
---@field row integer 0-based byte index.
---@field col integer 0-based byte index.
---@overload fun(row: integer, col: integer, opts: vim.Pos.Optional?): vim.Pos
local Pos = {}
Pos.__index = Pos

---@class vim.pos.new.Opts
---@inlinedoc
---@field bufnr? integer

---@package
---@param row integer
---@param col integer
---@param opts vim.Pos.Optional
function Pos:new(row, col, opts)
  validate('row', row, 'number')
  validate('col', col, 'number')
  validate('opts', opts, 'table', true)

  ---@type vim.Pos
  self = setmetatable({}, self)
  self.row = row
  self.col = col

  opts = opts or {}
  self.bufnr = opts.bufnr

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

---@diagnostic disable-next-line: param-type-mismatch
setmetatable(Pos, {
  __call = Pos.new,
})

return Pos
