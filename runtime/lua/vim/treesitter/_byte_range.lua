local bit = require('bit')
local rshift = bit.rshift

local M = {}

--- Indices are 0-based.
local function memmove(dst, dst_begin, src, src_begin, count)
  -- Accessing an undefined field of a global variable
  -- luacheck: push ignore 143
  if table.move then
    table.move(src, 1 + src_begin, 1 + src_begin + count - 1, 1 + dst_begin, dst)
    -- luacheck: pop
  else
    if dst == src then
      if dst_begin == src_begin then
        return
      end
      assert(dst_begin <= src_begin, 'not implemented')
    end

    for i = 1, count do
      dst[dst_begin + i] = src[src_begin + i]
    end
  end
end

---Used as 0-based, end exclusive
---@class ByteRange
---@inlinedoc
---@field [1] integer begin byte
---@field [2] integer end byte

---@param ranges ByteRange[]
---@param edit_b integer
---@param edit_e_old integer
---@return integer index
function M.ranges_find_first_edited(ranges, edit_b, edit_e_old)
  local count = #ranges

  local bi = 1
  local ei = 1 + count
  if edit_b == edit_e_old then
    while bi < ei do
      local mi = rshift(bi + ei, 1)
      local meb = ranges[mi][2]
      if edit_b <= meb then
        ei = mi
      else
        bi = mi + 1
      end
    end
  else
    while bi < ei do
      local mi = rshift(bi + ei, 1)
      local meb = ranges[mi][2]
      if edit_b < meb then
        ei = mi
      else
        bi = mi + 1
      end
    end
  end

  return ei
end

---Find 0-based [begin_i, end_i) that the given range next to or intersects.
---@param ranges ByteRange[] Sorted, non-overlapping.
---@param byte_b integer
---@param byte_e integer
local function ranges_find_touching(ranges, byte_b, byte_e)
  local count = #ranges

  -- Find first range that the given range can be combined with.
  -- Find first range that the given range is before.

  local bi = 0
  local ei = count
  -- to continue searching the second position.
  local end_in_sync = true
  ---@type integer
  local bi_end
  ---@type integer
  local ei_end

  while bi < ei do
    local mi = rshift(bi + ei, 1)
    local mid_beg = ranges[1 + mi][1]
    local mid_end = ranges[1 + mi][2]

    local satisfied_begin = byte_b <= mid_end
    local satisfied_end = byte_e < mid_beg
    if satisfied_begin ~= satisfied_end and end_in_sync then
      end_in_sync = false
      bi_end = bi
      ei_end = ei
    end
    if satisfied_begin then
      ei = mi
    else
      bi = mi + 1
    end
  end

  if end_in_sync then
    ei_end = ei
  else
    while bi_end < ei_end do
      local mi = rshift(bi_end + ei_end, 1)
      local mid_beg = ranges[1 + mi][1]
      if byte_e < mid_beg then
        ei_end = mi
      else
        bi_end = mi + 1
      end
    end
  end

  return ei, ei_end
end

---Inserts a range into a sorted array of non-overlapping (possibly touching) ranges.
---After insertion, ranges are not overlapping, and not touching the inserted range.
---@param ranges ByteRange[]
---@param byte_b integer
---@param byte_e integer
function M.ranges_insert(ranges, byte_b, byte_e)
  local count = #ranges
  local b, e = ranges_find_touching(ranges, byte_b, byte_e)

  if b < e then
    ranges[1 + b][1] = math.min(byte_b, ranges[1 + b][1])
    ranges[1 + b][2] = math.max(byte_e, ranges[1 + e - 1][2])

    if e - b > 1 then
      local move_begin = b + 1
      local move_count = count - e
      memmove(ranges, move_begin, ranges, e, move_count)
      for i = move_begin + move_count, count - 1 do
        ranges[1 + i] = nil
      end
    end
  else
    table.insert(ranges, 1 + b, { byte_b, byte_e })
  end
end

---Edit a range like teee-sitter would've edited a node.
---But only if the edit itersects the range.
---@param range ByteRange
---@param edit_b integer
---@param edit_e_old integer
---@param edit_e_new integer
---@return boolean changed
function M.edit_intersects(range, edit_b, edit_e_old, edit_e_new)
  -- See `ts_subtree_edit()` in tree-sitter.
  if range[1] >= edit_e_old then
    -- Edit is entirely before the range.
    return false
  elseif edit_b < range[1] then
    -- Edit starts before the range and ends inside/after.
    -- Move the tree to the end of the edit and shrink accordingly.
    range[1] = M.clamp(edit_e_new)
    range[2] = M.clamp(range[1] + math.max(range[2] - edit_e_old, 0))
    return true
  elseif edit_b < range[2] or (edit_b == range[2] and edit_b == edit_e_old) then
    -- Edit starts inside the range.
    -- Include the edit in the range (yes, even if old_end is outside the range).
    range[2] = M.clamp(edit_e_new + math.max(range[2] - edit_e_old, 0))
    return true
  else
    -- Edit is entirely after the range.
    return false
  end
end

---@param range ByteRange
---@param sliced_by_b integer
---@param sliced_by_e integer
---@return ByteRange[] leftovers
---@return ByteRange? difference
local function slice(range, sliced_by_b, sliced_by_e)
  ---@type ByteRange[]
  local leftovers
  ---@type ByteRange?
  local difference

  local range_b = range[1]
  local range_e = range[2]

  if range_b < sliced_by_b and sliced_by_e < range_e then
    -- Slice completely inside
    leftovers = { { range_b, sliced_by_b }, { sliced_by_e, range_e } }
    difference = { sliced_by_b, sliced_by_e }
  elseif sliced_by_b <= range_b and range_e <= sliced_by_e then
    --- Slice completely covers
    leftovers = {}
    difference = { range_b, range_e }
  elseif range_b < sliced_by_e and sliced_by_e < range_e then
    -- Slice is cutting beginning of the range
    difference = { range_b, sliced_by_e }
    leftovers = { { sliced_by_e, range_e } }
  elseif range_b < sliced_by_b and sliced_by_b < range_e then
    -- Slice is cutting end of the range
    leftovers = { { range_b, sliced_by_b } }
    difference = { sliced_by_b, range_e }
  else
    -- No intersection
    leftovers = { range }
  end

  return leftovers, difference
end

---Find 0-based [begin_i, end_i) that the given range intersects with.
---0-width ranges are not considered intersecting
---when they are next to the given range.
---@param ranges ByteRange[] Sorted, non-overlapping.
---@param byte_b integer
---@param byte_e integer
local function ranges_find_intersecting(ranges, byte_b, byte_e)
  local count = #ranges

  -- Find first range that the given range intersects with.
  -- Find first range that the given range is before.

  local bi = 0
  local ei = count
  -- to continue searching the second position.
  local end_in_sync = true
  ---@type integer
  local bi_end
  ---@type integer
  local ei_end

  while bi < ei do
    local mi = rshift(bi + ei, 1)
    local mid_beg = ranges[1 + mi][1]
    local mid_end = ranges[1 + mi][2]

    local satisfied_begin = byte_b < mid_end
    local satisfied_end = byte_e <= mid_beg
    if satisfied_begin ~= satisfied_end and end_in_sync then
      end_in_sync = false
      bi_end = bi
      ei_end = ei
    end
    if satisfied_begin then
      ei = mi
    else
      bi = mi + 1
    end
  end

  if end_in_sync then
    ei_end = ei
  else
    while bi_end < ei_end do
      local mi = rshift(bi_end + ei_end, 1)
      local mid_beg = ranges[1 + mi][1]
      if byte_e <= mid_beg then
        ei_end = mi
      else
        bi_end = mi + 1
      end
    end
  end

  return ei, ei_end
end

---@param ranges ByteRange[] Sorted, non-overlapping, possibly touching, no 0-width.
---@param byte_b integer
---@param byte_e integer
---@return ByteRange[] difference
function M.ranges_slice(ranges, byte_b, byte_e)
  local b, e = ranges_find_intersecting(ranges, byte_b, byte_e)
  local intersect_begin = b
  local intersect_end = e

  local result = {}
  if intersect_end - intersect_begin == 1 then
    local left, diff = slice(ranges[1 + intersect_begin], byte_b, byte_e)
    if #left >= 1 then
      ranges[1 + intersect_begin] = left[1]
      if #left == 2 then
        table.insert(ranges, 1 + intersect_begin + 1, left[2])
      end
    end

    if diff then
      table.insert(result, diff)
    end
  elseif intersect_end - intersect_begin > 1 then
    local left, diff1 = slice(ranges[1 + intersect_begin], byte_b, byte_e)
    local left2, diff2 = slice(ranges[1 + intersect_end - 1], byte_b, byte_e)

    assert(#left <= 1)
    assert(#left2 <= 1)
    for _, r in ipairs(left2) do
      table.insert(left, r)
    end
    assert(#left <= intersect_end - intersect_begin)

    if diff1 then
      table.insert(result, diff1)
    end
    for i = intersect_begin + 1, intersect_end - 2 do
      table.insert(result, ranges[i])
    end
    if diff2 then
      table.insert(result, diff2)
    end

    local c1 = #left
    memmove(ranges, intersect_begin, left, 0, c1)
    local c2 = #ranges - intersect_end
    memmove(ranges, intersect_begin + c1, ranges, intersect_end, c2)

    for i = intersect_begin + c1 + c2, #ranges - 1 do
      ranges[1 + i] = nil
    end
  end

  return result
end

local max = 2 ^ 32 - 1

---@param byte integer
function M.clamp(byte)
  return math.min(math.max(0, byte), max)
end

return M
