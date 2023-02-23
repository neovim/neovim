local api = vim.api

local M = {}

---@alias Range4 {[1]: integer, [2]: integer, [3]: integer, [4]: integer}
---@alias Range6 {[1]: integer, [2]: integer, [3]: integer, [4]: integer, [5]: integer, [6]: integer}

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
---@param r1 Range4|Range6
---@param r2 Range4|Range6
---@return boolean
function M.intercepts(r1, r2)
  local off_1 = #r1 == 6 and 1 or 0
  local off_2 = #r1 == 6 and 1 or 0

  local srow_1, scol_1, erow_1, ecol_1 = r1[1], r2[2], r1[3 + off_1], r1[4 + off_1]
  local srow_2, scol_2, erow_2, ecol_2 = r2[1], r2[2], r2[3 + off_2], r2[4 + off_2]

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
---@param r1 Range4|Range6
---@param r2 Range4|Range6
---@return boolean whether r1 contains r2
function M.contains(r1, r2)
  local off_1 = #r1 == 6 and 1 or 0
  local off_2 = #r1 == 6 and 1 or 0

  local srow_1, scol_1, erow_1, ecol_1 = r1[1], r2[2], r1[3 + off_1], r1[4 + off_1]
  local srow_2, scol_2, erow_2, ecol_2 = r2[1], r2[2], r2[3 + off_2], r2[4 + off_2]

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
---@param range Range4
---@return Range6
function M.add_bytes(source, range)
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
