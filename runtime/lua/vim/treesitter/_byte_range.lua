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
      assert(dst_begin <= src_begin, 'Not implemented')
    end

    for i = 1, count do
      dst[dst_begin + i] = src[src_begin + i]
    end
  end
end

---@param ranges [integer, integer][] Sorted, non-overlapping.
---@param edit_b integer
---@param edit_e_old integer
---@return integer index
function M.ranges_find_first_edited(ranges, edit_b, edit_e_old)
  local bi = 1
  local ei = 1 + #ranges
  while bi < ei do
    local mi = rshift(bi + ei, 1)
    local meb = ranges[mi][2]

    -- see tree-sitter ts_subtree_edit()
    local cmp ---@type boolean
    if edit_b == edit_e_old then
      cmp = edit_b <= meb
    else
      cmp = edit_b < meb
    end

    if cmp then
      ei = mi
    else
      bi = mi + 1
    end
  end

  return ei
end

---Find 0-based [`begin_i`, `end_i`) that the given range is next to or intersects.
---@param ranges [integer, integer][] Sorted, non-overlapping.
---@param byte_b integer
---@param byte_e integer
---@return integer begin_i 0-based.
---@return integer end_i 0-based.
local function ranges_find_touching(ranges, byte_b, byte_e)
  -- Find first range that the given range can be combined with.
  -- Find first range that the given range is before.
  local bi = 0
  local ei = #ranges
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
---@param ranges [integer, integer][]
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
---@param range [integer, integer]
---@param edit_b integer
---@param edit_e_old integer
---@param edit_e_new integer
function M.adjust_if_intersects(range, edit_b, edit_e_old, edit_e_new)
  -- See `ts_subtree_edit()` in tree-sitter.
  if range[1] >= edit_e_old then
    -- Edit is entirely before the range.
    return
  elseif edit_b < range[1] then
    -- Edit starts before the range and ends inside/after.
    -- Move the tree to the end of the edit and shrink accordingly.
    range[1] = M.clamp(edit_e_new)
    range[2] = M.clamp(range[1] + math.max(range[2] - edit_e_old, 0))
  elseif edit_b < range[2] or (edit_b == range[2] and edit_b == edit_e_old) then
    -- Edit starts inside the range.
    -- Include the edit in the range (yes, even if old_end is outside the range).
    range[2] = M.clamp(edit_e_new + math.max(range[2] - edit_e_old, 0))
  end
  -- else the edit is entirely after the range.
end

local max = 2 ^ 32 - 1

---@param byte integer
function M.clamp(byte)
  return math.min(math.max(0, byte), max)
end

return M
