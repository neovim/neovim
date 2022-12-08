-- If you are given a range like { 0, 0, 0, 4 }, you can pass this around to any
-- child LanguageTrees easily. But if you have used a region like the one
-- marked with xs below...
--
-- /// xxxxxxxx
-- /// xxxx
-- /// xxxxxxxxxxx
--
-- ... then when your child LanguageTree returns its injection query matches,
-- if those matches are multi-line matches (like a fenced code block in markdown),
-- then they will clobber the starts of lines. You'll get a region like so:
--
-- /// xxxxxxxx
-- xxxxxxxx
-- xxxxxxxxxxxxxxx
--
-- And hence any 3rd-level child parsers of that one will be working in a range
-- with some extra comment marks or whatever it is in the middle of it.
--
-- So we have to be careful to split up any ranges when passing them to a child
-- LanguageTree. This file implements that.

---@alias Range6 number[]

local M = {}

-- http://lua-users.org/wiki/BinarySearch
-- Avoid heap allocs for performance
local default_fcompval = function(value)
  return value
end
local fcompf = function(a, b)
  return a < b
end
local fcompr = function(a, b)
  return a > b
end

--- Finds values in a _sorted_ list using binary search.
--- If present, returns the range of indices that are == to `value`
--- If absent, returns the insertion point (duplicated), which may go off the end (#t + 1)
---@return integer range start
---@return integer range end
---@return boolean true if value was present
function M.binsearch(t, value, fcompval, reversed, start_point, end_point)
  -- Initialise functions
  fcompval = fcompval or default_fcompval
  local fcomp = reversed and fcompr or fcompf
  --  Initialise numbers
  local iStart, iEnd, iMid = 1, #t, 0
  if start_point ~= nil then
    iStart = start_point
  end
  if end_point ~= nil then
    iEnd = math.min(iEnd, end_point)
  end
  local iState = 0
  -- Binary Search
  while iStart <= iEnd do
    -- calculate middle
    iMid = math.floor((iStart + iEnd) / 2)
    -- get compare value
    local value2 = fcompval(t[iMid])
    -- get all values that match
    if value == value2 then
      local tfound, num = { iMid, iMid }, iMid - 1
      while num > 0 and value == fcompval(t[num]) do
        tfound[1], num = num, num - 1
      end
      num = iMid + 1
      while num <= #t and value == fcompval(t[num]) do
        tfound[2], num = num, num + 1
      end
      local from, to = unpack(tfound)
      return from, to, true
      -- keep searching
    elseif fcomp(value, value2) then
      iEnd = iMid - 1
      iState = 0
    else
      iStart = iMid + 1
      iState = 1
    end
  end
  -- modified to return the right place for such a value to be inserted, with 'false'
  -- indicating it wasn't in there already
  return iMid + iState, iMid + iState, false
end

---@param range Range6
---@return integer
---@return integer
local function range_bytes(range)
  return range[3], range[6]
end

---@param dst Range6
---@param src Range6
local function copy_start(dst, src)
  dst[1] = src[1]
  dst[2] = src[2]
  dst[3] = src[3]
end

---@param dst Range6
---@param src Range6
local function copy_end(dst, src)
  dst[4] = src[4]
  dst[5] = src[5]
  dst[6] = src[6]
end

---@return number
local function range_start(range)
  return range[3]
end

---@return number
local function range_end(range)
  return range[6]
end

---@return boolean
local function range_empty_invalid(range)
  return range[3] >= range[6]
end

---@param needle Range6
---@param haystack Range6[]
---@return Range6[]
function M.find_overlaps(needle, haystack)
  -- assume region sorted
  local from, to = range_bytes(needle)
  local istart, _, _ = M.binsearch(haystack, from, range_end)
  local _, iend, exists = M.binsearch(haystack, to, range_start, false, istart)
  if not exists then
    iend = iend - 1
  end
  local slice = {}
  for i = istart, iend do
    table.insert(slice, haystack[i])
  end
  return slice
end

-- This is the idea:
-- parent: xxxxxx    xxxx  xxxxx
-- child:    ----------------
-- result:   oooo    iiii  oo

-- We assume the overlaps are sorted.
function M.clip_range_with_overlaps(child, overlapping)
  local child_from, child_to = range_bytes(child)
  local results = {}

  if #overlapping == 0 then
    return results
  end

  -- step 1, clone the ranges, and coalesce sequences of adjacent ranges
  -- cloning them avoids messing up the parent range. We don't have to
  -- coalesce, but we may as well.
  -- (coalescing = avoid splitting { 0, 4 } against {{0, 2}, {2, 4})
  local last_r = { unpack(overlapping[1]) }
  local coalesced = {}
  if #overlapping > 1 then
    for i = 2, #overlapping do
      local r = overlapping[i]
      if range_end(last_r) == range_start(r) then
        -- expand the previous range
        copy_end(last_r, r)
      else
        table.insert(coalesced, last_r)
        last_r = { unpack(r) }
      end
    end
  end
  table.insert(coalesced, last_r)

  -- step 2, take the overlaps, and remove any bits that arent inside
  -- the child range
  for _, parent in ipairs(coalesced) do
    if range_empty_invalid(parent) then
      goto continue
    end

    -- parent: xxxxxx    xxxxxxxx
    -- child:    ------    ----
    -- result:   oooo      oooo
    if range_start(parent) < child_from then
      copy_start(parent, child)
    end

    -- parent:   xxxxxx  xxxxxxxx
    -- child:  ------      ----
    -- result:   oooo      oooo
    if range_end(parent) > child_to then
      copy_end(parent, child)
    end

    if range_empty_invalid(parent) then
      goto continue
    end

    -- if not modified by previous rules, then it's just wholly contained
    -- parent:   xxxxxx
    -- child:  -----------
    -- result:   iiiiii
    table.insert(results, parent)
    ::continue::
  end

  return results
end

---@param child_region Range6[]
---@param parent_region Range6[]
function M.clip_region(child_region, parent_region)
  if child_region == nil then
    return {}
  end
  if not parent_region or #parent_region == 0 then
    return child_region
  end
  local clipped_region = {}
  for _, child_range in ipairs(child_region) do
    local overlapping = M.find_overlaps(child_range, parent_region)
    local clipped = M.clip_range_with_overlaps(child_range, overlapping)
    for _, subrange in ipairs(clipped) do
      table.insert(clipped_region, subrange)
    end
  end
  return clipped_region
end

return M
