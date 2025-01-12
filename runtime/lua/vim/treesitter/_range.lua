local api = vim.api

local M = {}

---@class Range2
---@inlinedoc
---@field [1] integer start row
---@field [2] integer end row

---@class Range4
---@inlinedoc
---@field [1] integer start row
---@field [2] integer start column
---@field [3] integer end row
---@field [4] integer end column

---@class Range6
---@inlinedoc
---@field [1] integer start row
---@field [2] integer start column
---@field [3] integer start bytes
---@field [4] integer end row
---@field [5] integer end column
---@field [6] integer end bytes

---@alias Range Range2|Range4|Range6

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
  if #r == 2 then
    return r[1], 0, r[2], 0
  end
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

--- @private
--- @param source integer|string
--- @param index integer
--- @return integer
local function get_offset(source, index)
  if index == 0 then
    return 0
  end

  if type(source) == 'number' then
    return api.nvim_buf_get_offset(source, index)
  end

  local byte = 0
  local next_offset = source:gmatch('()\n')
  local line = 1
  while line <= index do
    byte = next_offset() --[[@as integer]]
    line = line + 1
  end

  return byte
end

---@private
---@param source integer|string
---@param range Range
---@return Range6
function M.add_bytes(source, range)
  if type(range) == 'table' and #range == 6 then
    return range --[[@as Range6]]
  end

  local start_row, start_col, end_row, end_col = M.unpack4(range)
  -- TODO(vigoux): proper byte computation here, and account for EOL ?
  local start_byte = get_offset(source, start_row) + start_col
  local end_byte = get_offset(source, end_row) + end_col

  return { start_row, start_col, start_byte, end_row, end_col, end_byte }
end

---@param source integer|string
function M.line_byte(source, index)
  if type(source) == 'number' then
    local count = api.nvim_buf_line_count(source)
    if index <= 0 then
      return 0
    end
    if index >= count then
      return 2 ^ 32 - 1
    end
    return api.nvim_buf_get_offset(source, index)
  end

  local byte = 0
  local next_offset = source:gmatch('()\n')
  local line = 1
  while line <= index do
    local next = next_offset() --[[@as integer?]]
    if not next then
      return 2 ^ 32 - 1
    end
    byte = next
    line = line + 1
  end

  return byte
end

---@alias Point { [1]: integer, [2]: integer, [3]: integer }

local max = 2 ^ 32 - 1
---@param byte integer
local function clamp(byte)
  return math.min(math.max(0, byte), max)
end

---@param row integer
---@param col integer
---@param byte integer
---@param off Point
local function point_add(row, col, byte, off)
  if row > 0 then
    row = clamp(row + off[1])
  else
    row = clamp(off[1])
    col = clamp(col + off[2])
  end
  byte = clamp(byte + off[3])

  return row, col, byte
end

---@param row integer
---@param col integer
---@param byte integer
---@param off Point
local function point_sub(row, col, byte, off)
  if row > off[1] then
    row = clamp(row - off[1])
  elseif row == off[1] then
    row = 0
    col = clamp(col - off[2])
  else
    row = 0
    col = 0
  end
  byte = clamp(byte - off[3])

  return row, col, byte
end

---range is end-exclusive, 0-based.
---@param range Range6
---@param off Point
function M.range6_add(range, off)
  range[1], range[2], range[3] = point_add(range[1], range[2], range[3], off)
  range[4], range[5], range[6] = point_add(range[4], range[5], range[6], off)
end

---range is end-exclusive, 0-based.
---@param range Range6
---@param off Point
function M.range6_sub(range, off)
  range[1], range[2], range[3] = point_sub(range[1], range[2], range[3], off)
  range[4], range[5], range[6] = point_sub(range[4], range[5], range[6], off)
end

---Edit a range like teee-sitter would've edited a node.
---range is end-exclusive, 0-based.
---@param range Range6
---@param beg Point
---@param old_end Point
---@param new_end Point
---@return boolean changed
function M.range6_edit(range, beg, old_end, new_end)
  -- See `ts_subtree_edit()` in tree-sitter.
  if range[3] >= old_end[3] then
    -- Edit is entirely before the range.
    local len = range[6] - range[3]
    M.range6_sub(range, old_end)
    M.range6_add(range, new_end)
    local len_new = range[6] - range[3]
    -- Length can change if the end position was clamped to UINT_MAX.
    return len ~= len_new
  elseif beg[3] < range[3] then
    -- Edit starts before the range and ends inside/after.
    -- Move the tree to the end of the edit and shrink accordingly.
    M.range6_sub(range, old_end)
    M.range6_add(range, new_end)
    return true
  elseif beg[3] < range[6] or (beg[3] == range[6] and beg[3] == new_end[3]) then
    -- Edit starts inside the range.
    -- Include the edit in the range (yes, even if old_end is outside the range).
    range[4], range[5], range[6] = point_sub(range[4], range[5], range[6], old_end)
    range[4], range[5], range[6] = point_add(range[4], range[5], range[6], new_end)
    return true
  else
    -- Edit is entirely after the range.
    return false
  end
end

return M
