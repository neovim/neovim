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

--- TODO(ofseed): Make it work for unloaded buffers.
---@param bufnr integer
---@param row integer
local function get_line(bufnr, row)
  return api.nvim_buf_get_lines(bufnr, row, row + 1, true)[1]
end

---@param pos vim.Pos
---@param position_encoding lsp.PositionEncodingKind
local function to_lsp_position(pos, position_encoding)
  validate('pos', pos, 'table')
  validate('position_encoding', position_encoding, 'string')

  local bufnr = assert(pos.bufnr, 'position is not a buffer position')
  local row, col = pos.row, pos.col
  -- When on the first character,
  -- we can ignore the difference between byte and character.
  if col > 0 then
    col = vim.str_utfindex(get_line(bufnr, row), position_encoding, col, false)
  end

  ---@type lsp.Position
  return { line = row, character = col }
end

---@param bufnr integer
---@param pos lsp.Position
---@param position_encoding lsp.PositionEncodingKind
local function from_lsp_position(bufnr, pos, position_encoding)
  validate('bufnr', bufnr, 'number')
  validate('pos', pos, 'table')
  validate('position_encoding', position_encoding, 'string')

  local row, col = pos.line, pos.character
  -- When on the first character,
  -- we can ignore the difference between byte and character.
  if col > 0 then
    col = vim.str_byteindex(get_line(bufnr, row), position_encoding, col)
  end

  return Pos:new(row, col, { bufnr = bufnr })
end

---@overload fun(pos: vim.Pos, position_encoding: lsp.PositionEncodingKind): lsp.Position
---@overload fun(bufnr: integer, pos: lsp.Position, position_encoding: lsp.PositionEncodingKind): vim.Pos
function Pos.lsp(...)
  local args = { ... }
  if #args == 2 then
    return to_lsp_position(...)
  elseif #args == 3 then
    return from_lsp_position(...)
  else
    error('invalid parameters')
  end
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
