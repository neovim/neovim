local api = vim.api

local M = {}

---@class Range4
---@field [1] integer start row
---@field [2] integer start column
---@field [3] integer end row
---@field [4] integer end column

---@class Range6
---@field [1] integer start row
---@field [2] integer start column
---@field [3] integer start bytes
---@field [4] integer end row
---@field [5] integer end column
---@field [6] integer end bytes

---@alias Range Range4|Range6

---@private
---@param a_row integer
---@param a_col integer
---@param b_row integer
---@param b_col integer
---@return integer
--- 1: a > b
--- 0: a == b
--- -1: a < b
local function cmp_pos(a_row, a_col, b_row, b_col)
  if a_row == b_row then
    if a_col > b_col then
      return 1
    elseif a_col < b_col then
      return -1
    else
      return 0
    end
  elseif a_row > b_row then
    return 1
  end

  return -1
end

M.cmp_pos = {
  lt = function(...)
    return cmp_pos(...) == -1
  end,
  le = function(...)
    return cmp_pos(...) ~= 1
  end,
  gt = function(...)
    return cmp_pos(...) == 1
  end,
  ge = function(...)
    return cmp_pos(...) ~= -1
  end,
  eq = function(...)
    return cmp_pos(...) == 0
  end,
  ne = function(...)
    return cmp_pos(...) ~= 0
  end,
}

setmetatable(M.cmp_pos, { __call = cmp_pos })

---@private
---Check if a variable is a valid range object
---@param r any
---@return boolean
function M.validate(r)
  if type(r) ~= 'table' or #r ~= 6 and #r ~= 4 then
    return false
  end

  for _, e in
    ipairs(r --[[@as any[] ]])
  do
    if type(e) ~= 'number' then
      return false
    end
  end

  return true
end

---@private
---@param r1 Range
---@param r2 Range
---@return boolean
function M.intercepts(r1, r2)
  local srow_1, scol_1, erow_1, ecol_1 = M.unpack4(r1)
  local srow_2, scol_2, erow_2, ecol_2 = M.unpack4(r2)

  -- r1 is above r2
  if M.cmp_pos.le(erow_1, ecol_1, srow_2, scol_2) then
    return false
  end

  -- r1 is below r2
  if M.cmp_pos.ge(srow_1, scol_1, erow_2, ecol_2) then
    return false
  end

  return true
end

---@private
---@param r Range
---@return integer, integer, integer, integer
function M.unpack4(r)
  local off_1 = #r == 6 and 1 or 0
  return r[1], r[2], r[3 + off_1], r[4 + off_1]
end

---@private
---@param r Range6
---@return integer, integer, integer, integer, integer, integer
function M.unpack6(r)
  return r[1], r[2], r[3], r[4], r[5], r[6]
end

---@private
---@param r1 Range
---@param r2 Range
---@return boolean whether r1 contains r2
function M.contains(r1, r2)
  local srow_1, scol_1, erow_1, ecol_1 = M.unpack4(r1)
  local srow_2, scol_2, erow_2, ecol_2 = M.unpack4(r2)

  -- start doesn't fit
  if M.cmp_pos.gt(srow_1, scol_1, srow_2, scol_2) then
    return false
  end

  -- end doesn't fit
  if M.cmp_pos.lt(erow_1, ecol_1, erow_2, ecol_2) then
    return false
  end

  return true
end

---@private
---@param source integer|string
---@param range Range
---@return Range6
function M.add_bytes(source, range)
  if type(range) == 'table' and #range == 6 then
    return range --[[@as Range6]]
  end

  local start_row, start_col, end_row, end_col = range[1], range[2], range[3], range[4]
  local start_byte = 0
  local end_byte = 0
  -- TODO(vigoux): proper byte computation here, and account for EOL ?
  if type(source) == 'number' then
    -- Easy case, this is a buffer parser
    start_byte = api.nvim_buf_get_offset(source, start_row) + start_col
    end_byte = api.nvim_buf_get_offset(source, end_row) + end_col
  elseif type(source) == 'string' then
    -- string parser, single `\n` delimited string
    start_byte = vim.fn.byteidx(source, start_col)
    end_byte = vim.fn.byteidx(source, end_col)
  end

  return { start_row, start_col, start_byte, end_row, end_col, end_byte }
end

return M
