local Range = require('vim.treesitter._range')

local end_point = Range.end_point
local start_point = Range.start_point

---@class ITNode
---@field range Range6
---Since we key nodes by the convex hull of their region, we must explicitly store the region information as well.
---@field region Range6[]
---@field index integer
---@field left ITNode?
---@field right ITNode?
---@field height integer
---@field max_end Point
local ITNode = {}
ITNode.__index = ITNode

---@param range Range6
---@param region Range6[]
---@param index integer
---@return ITNode
function ITNode.new(range, region, index)
  return setmetatable({
    range = range,
    left = nil,
    index = index,
    right = nil,
    height = 1,
    region = region,
    max_end = end_point(range),
  }, ITNode)
end

---@param node ITNode?
---@return integer
local function height(node)
  return node and node.height or 0
end

---@param node ITNode
---@return integer
local function balance_factor(node)
  return height(node.left) - height(node.right)
end

---@param node ITNode
local function node_update_height(node)
  node.height = math.max(height(node.left), height(node.right)) + 1
end

---@param node ITNode
local function update_max_end(node)
  local max_end = node.max_end
  if node.left and max_end < node.left.max_end then
    max_end = node.left.max_end
  end
  if node.right and max_end < node.right.max_end then
    max_end = node.right.max_end
  end
  node.max_end = max_end
end

---@param y ITNode
---@return ITNode
local function rotate_right(y)
  local x = assert(y.left)
  y.left = x.right
  x.right = y
  node_update_height(x)
  node_update_height(y)
  update_max_end(x)
  update_max_end(y)
  return x
end

---@param x ITNode
---@return ITNode
local function rotate_left(x)
  local y = assert(x.right)
  x.right = y.left
  y.left = x
  node_update_height(x)
  node_update_height(y)
  update_max_end(x)
  update_max_end(y)
  return y
end

---@param node ITNode
---@return ITNode
local function rebalance(node)
  node_update_height(node)
  local balance = balance_factor(node)

  -- Left Heavy
  if balance > 1 then
    if balance_factor(node.left) < 0 then
      node.left = rotate_left(node.left) -- Left-Right case
    end
    return rotate_right(node) -- Left-Left case
  end

  -- Right Heavy
  if balance < -1 then
    if balance_factor(node.right) > 0 then
      node.right = rotate_right(node.right) -- Right-Left case
    end
    return rotate_left(node) -- Right-Right case
  end

  return node -- Already balanced
end

---@param node ITNode
---@param range Range6
---@param ranges Range6[]
---@param index integer
local function insert(node, range, ranges, index)
  if not node then
    return ITNode.new(range, ranges, index)
  end

  if start_point(range) < start_point(node.range) then
    node.left = insert(node.left, range, ranges, index)
  elseif start_point(range) > start_point(node.range) then
    node.right = insert(node.right, range, ranges, index)
  else
    return node
  end

  update_max_end(node)

  return rebalance(node)
end

---@class ITree
---@field root ITNode?
local ITree = {}
ITree.__index = ITree

function ITree.new()
  return setmetatable({ root = nil }, ITree)
end

---@param range Range6
---@param region Range6[]
---@param index integer
function ITree:insert(range, region, index)
  self.root = insert(self.root, range, region, index)
end

---@param regions Range6[][]
---@param start integer
---@param stop integer
---@param callback function
local function sorted_regions_to_tree(regions, start, stop, callback)
  if start > stop then
    return nil
  end

  local mid = math.floor((start + stop) / 2)
  local region = regions[mid]
  local r1 = region[1]
  local r2 = region[#region]
  local combined = { r1[1], r1[2], r1[3], r2[4], r2[5], r2[6] }
  local node = ITNode.new(combined, region, mid)

  callback()

  node.left = sorted_regions_to_tree(regions, start, mid - 1, callback)
  node.right = sorted_regions_to_tree(regions, mid + 1, stop, callback)

  update_max_end(node)
  node_update_height(node)

  return node
end

---@param ranges Range6[][]
---@param callback function A callback to run after each node is created.
function ITree.from_sorted_regions(ranges, callback)
  return setmetatable({ root = sorted_regions_to_tree(ranges, 1, #ranges, callback) }, ITree)
end

---@param node ITNode
---@param range Range
---@param result ITNode[]
local function find_overlapping_intervals(node, range, result)
  if Range.intercepts(node.range, range) then
    table.insert(result, node)
  end

  if node.left and start_point(range) <= node.left.max_end then
    find_overlapping_intervals(node.left, range, result)
  end

  if node.right and start_point(node.range) <= end_point(range) then
    find_overlapping_intervals(node.right, range, result)
  end
end

---@param range Range
---@return ITNode[]
function ITree:find_overlapping_intervals(range)
  ---@type ITNode[]
  local result = {}
  if self.root then
    find_overlapping_intervals(self.root, range, result)
  end
  return result
end

---@param node ITNode
---@param list ITNode[]
local function inorder_traversal(node, list)
  if not node then
    return
  end
  inorder_traversal(node.left, list)
  table.insert(list, node)
  inorder_traversal(node.right, list)
end

---@return ITNode[]
function ITree:nodes()
  ---@type ITNode[]
  local ranges = {}
  inorder_traversal(self.root, ranges)
  return ranges
end

return ITree
