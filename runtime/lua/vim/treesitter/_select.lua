local Range = require('vim.treesitter._range')

--- This is (currently only) used for saving what child one is in when doing
--- `select_parent` so that if they later `select_child` on the parent-node,
--- they get back to the child-node they were in instead of the parents first
--- child-node.
---
--- @type {[integer]:vim.treesitter.select.node,[any]:any}
local history = {
  --- @type integer?
  bufnr = nil,

  --- @type integer?
  changedtick = nil,

  --- @type string?
  current_node_id = nil,
}

--- The reason for a wrapper around `TSNode` is because we need to store the
--- information about which tstree-range they are in (as a tstree may be
--- disjointed), where region is the return value of
--- `TSTree:included_ranges(false)` with next to eachother ranges combined
--- (e.g. {{0,0,1,1},{1,1,2,2}} -> {{0,0,2,2}}).
---
--- @class vim.treesitter.select.node
--- @field node TSNode
--- @field top vim.treesitter.select.node.top

--- @class vim.treesitter.select.node.top: vim.treesitter.select.node
--- @field ltree vim.treesitter.LanguageTree
--- @field region Range4

local M = {}

--- @param node vim.treesitter.select.node
--- @return string
local function node_id(node)
  return ('%s:%s'):format(table.concat({ unpack(node.top.region) }, ':'), node.node:id())
end

--- @param r1 Range4
--- @param r2 Range4
--- @return Range4?
local function range_intersection(r1, r2)
  if not Range.intercepts(r1, r2) then
    return
  end

  local rs = Range.cmp_pos.le(r1[1], r1[2], r2[1], r2[2]) and r2 or r1
  local re = Range.cmp_pos.ge(r1[3], r1[4], r2[3], r2[4]) and r2 or r1
  return { rs[1], rs[2], re[3], re[4] }
end

--- @param r1 Range4
--- @param r2 Range4
--- @boolean
local function range_is_same(r1, r2)
  local srow_1, scol_1, erow_1, ecol_1 = Range.unpack4(r1)
  local srow_2, scol_2, erow_2, ecol_2 = Range.unpack4(r2)
  return srow_1 == srow_2 and scol_1 == scol_2 and erow_1 == erow_2 and ecol_1 == ecol_2
end

--- @param node vim.treesitter.select.node
--- @return Range4
local function node_range(node)
  local node_range_ = { node.node:range() }

  return range_intersection(node.top.region, node_range_) or { 0, 0, 0, 0 }
end

--- @param node1 vim.treesitter.select.node
--- @param node2 vim.treesitter.select.node
--- @return boolean
local function node_is_same_range(node1, node2)
  return range_is_same(node_range(node1), node_range(node2))
end

--- @param node vim.treesitter.select.node
--- @return boolean
local function node_is_size_0(node)
  local srow, scol, erow, ecol = Range.unpack4(node_range(node))
  return srow == erow and scol == ecol
end

--- @param tsnode TSNode
--- @param relative vim.treesitter.select.node
--- @return vim.treesitter.select.node
local function create_node(tsnode, relative)
  assert(tsnode:tree():root():equal(relative.top.node))

  --- @type vim.treesitter.select.node
  return {
    node = tsnode,
    top = relative.top,
  }
end

--- @param tree TSTree
--- @return Range4[]
local function tree_get_ranges(tree)
  --- @type Range4[]
  local regions = {}
  for _, tree_range in ipairs(tree:included_ranges(false)) do
    local prev_region = regions[#regions]

    if prev_region and prev_region[3] == tree_range[1] and prev_region[4] == tree_range[2] then
      regions[#regions] = { prev_region[1], prev_region[2], tree_range[3], tree_range[4] }
    else
      table.insert(regions, tree_range)
    end
  end
  return regions
end

--- @param tree TSTree
--- @param region Range4
--- @param ltree vim.treesitter.LanguageTree
--- @return vim.treesitter.select.node.top
local function create_top_node(tree, region, ltree)
  --- @type vim.treesitter.select.node.top
  local self = {
    node = tree:root(),
    top = {} --[[@as any]],
    ltree = ltree,
    region = region,
  }
  self.top = self
  return self
end

--- @param node1 vim.treesitter.select.node.top
--- @param node2 vim.treesitter.select.node.top
--- @return boolean
local function top_node_is_higher_priority(node1, node2)
  local srow1, scol1, erow1, ecol1 = Range.unpack4(node_range(node1))
  local srow2, scol2, erow2, ecol2 = Range.unpack4(node_range(node2))

  if M.TEST_SWITCH_PRIORITY then
    if Range.cmp_pos.ne(srow1, scol1, srow2, scol2) then
      return Range.cmp_pos.lt(srow1, scol1, srow2, scol2)
    elseif Range.cmp_pos.ne(erow1, ecol1, erow2, ecol2) then
      return Range.cmp_pos.lt(erow1, ecol1, erow2, ecol2)
    elseif node1.ltree:lang() ~= node2.ltree:lang() then
      return node1.ltree:lang() > node2.ltree:lang()
    end
    return node1.node:id() > node2.node:id()
  else
    if Range.cmp_pos.ne(srow1, scol1, srow2, scol2) then
      return Range.cmp_pos.gt(srow1, scol1, srow2, scol2)
    elseif Range.cmp_pos.ne(erow1, ecol1, erow2, ecol2) then
      return Range.cmp_pos.gt(erow1, ecol1, erow2, ecol2)
    elseif node1.ltree:lang() ~= node2.ltree:lang() then
      return node1.ltree:lang() < node2.ltree:lang()
    end
    return node1.node:id() < node2.node:id()
  end
end

--- @param range Range4
--- @param top_node vim.treesitter.select.node.top?
--- @param parent_chain vim.treesitter.select.node[]?
--- @return vim.treesitter.select.node|false|nil nil: no parser, false: outside of root-node
--- @return vim.treesitter.select.node[] either `parent_chain` or `alternative_nodes`
local function get_node(range, top_node, parent_chain)
  parent_chain = parent_chain or {}

  if not top_node then
    local parser = vim.treesitter.get_parser(nil, nil, { error = false })
    if not parser then
      return nil, {}
    end

    local tree = assert(parser:parse(range))[1]
    top_node = create_top_node(tree, assert(tree:included_ranges(false)[1]), parser)

    if not Range.contains(node_range(top_node), range) then
      return false, { top_node } --[[alternative_nodes]]
    end
  end

  assert(Range.contains(node_range(top_node), range))

  --- @param node vim.treesitter.select.node|vim.treesitter.select.node.top
  --- @return vim.treesitter.select.node|vim.treesitter.select.node.top
  local function node_ignore_overlapped_handle_injection(node)
    for _, child in pairs(top_node.ltree:children()) do
      for _, child_tree in ipairs(child:trees()) do
        for _, child_region in ipairs(tree_get_ranges(child_tree)) do
          local child_root_node_range = { child_tree:root():range() }
          local child_range = range_intersection(child_region, child_root_node_range)

          local child_top_node = create_top_node(child_tree, child_region, child)
          if
            child_range
            and Range.contains(child_range, range)
            and (
              not node.ltree
              or top_node_is_higher_priority(
                node --[[@as vim.treesitter.select.node.top]],
                child_top_node
              )
            )
          then
            return node_ignore_overlapped_handle_injection(child_top_node)
          elseif child_range and Range.intercepts(node_range(node), child_range) then
            local child_parent_tsnode =
              assert(top_node.node:named_descendant_for_range(unpack(child_range)))

            if
              (not node.ltree and vim.treesitter.is_ancestor(child_parent_tsnode, node.node))
              or (
                node.ltree
                and top_node_is_higher_priority(
                  node --[[@as vim.treesitter.select.node.top]],
                  child_top_node
                )
              )
            then
              return create_node(child_parent_tsnode, top_node)
            end
          end
        end
      end
    end

    return node
  end

  local tsnode = assert(top_node.node:named_descendant_for_range(unpack(range)))
  local node = create_node(tsnode, top_node)

  node = node_ignore_overlapped_handle_injection(node)
  if node.ltree then
    local root_node_range = { node.node:range() }
    local tree_range = node.top.region
    local actual_range = assert(range_intersection(tree_range, root_node_range))
    local parent_tsnode = assert(top_node.node:named_descendant_for_range(unpack(actual_range)))
    table.insert(parent_chain, create_node(parent_tsnode, top_node))

    --- @cast node vim.treesitter.select.node.top
    return get_node(range, node, parent_chain), parent_chain
  end
  --- @cast node vim.treesitter.select.node

  return node, parent_chain
end

--- @param node vim.treesitter.select.node
--- @param parent_chain vim.treesitter.select.node[]
--- @nodiscard
--- @return vim.treesitter.select.node?
--- @return vim.treesitter.select.node.top?
local function node_get_parent_no_normalize(node, parent_chain)
  local parent = node.node:parent()
  if parent then
    return create_node(parent, node)
  end

  return table.remove(parent_chain)
end

--- @param node vim.treesitter.select.node
--- @return vim.treesitter.select.node
local function node_normalize_up(node, parent_chain)
  while true do
    local parent = node_get_parent_no_normalize(node, parent_chain)
    if parent and node_is_same_range(parent, node) then
      node = parent
    else
      table.insert(parent_chain, parent)

      return node
    end
  end
  --- @diagnostic disable-next-line: missing-return
end

--- @param nodes vim.treesitter.select.node[]
--- @param node vim.treesitter.select.node.top
local function insert_remove_overlapped(nodes, node)
  local n = 1
  while nodes[n] do
    if Range.intercepts(node_range(nodes[n]), node_range(node)) then
      if
        not nodes
          [n] --[[@as any]]
          .ltree
        or top_node_is_higher_priority(nodes[n] --[[@as vim.treesitter.select.node.top]], node)
      then
        table.remove(nodes, n)
      else
        return
      end
    else
      local nrow, ncol, _, _ = Range.unpack4(node_range(nodes[n]))
      local _, _, erow, ecol = Range.unpack4(node_range(node))
      if Range.cmp_pos.le(erow, ecol, nrow, ncol) then
        table.insert(nodes, n, node)
        return
      end

      n = n + 1
    end
  end

  table.insert(nodes, node)
end

--- @param node vim.treesitter.select.node
--- @return vim.treesitter.select.node[]
local function node_get_children_no_normalize(node)
  --- @param child_ TSNode
  --- @return vim.treesitter.select.node
  local children = vim.tbl_map(function(child_)
    return create_node(child_, node)
  end, node.node:named_children())

  node.top.ltree:parse(node_range(node))

  for _, child in pairs(node.top.ltree:children()) do
    for _, child_tree in ipairs(child:trees()) do
      for _, child_region in ipairs(tree_get_ranges(child_tree)) do
        local child_root_node_range = { child_tree:root():range() }
        local child_range = range_intersection(child_region, child_root_node_range)

        if child_range and Range.contains(node_range(node), child_range) then
          local child_parent_tsnode =
            assert(node.top.node:named_descendant_for_range(unpack(child_range)))

          if node.node:equal(child_parent_tsnode) then
            local child_node = create_top_node(child_tree, child_region, child)

            insert_remove_overlapped(children, child_node)
          end
        end
      end
    end
  end

  return children
end

--- @param range Range4
--- @param node vim.treesitter.select.node
--- @return vim.treesitter.select.node?
local function get_node_contained_in_range(range, node)
  for _, child in ipairs(node_get_children_no_normalize(node)) do
    if Range.contains(range, node_range(child)) and not node_is_size_0(child) then
      return child
    elseif Range.intercepts(range, node_range(child)) and not node_is_size_0(child) then
      local smallest_node = get_node_contained_in_range(range, child)

      if smallest_node then
        return smallest_node
      end
    end
  end
end

--- @param node vim.treesitter.select.node
--- @return vim.treesitter.select.node
local function node_normalize_down(node)
  for _, child in ipairs(node_get_children_no_normalize(node)) do
    if node_is_same_range(node, child) then
      return node_normalize_down(child)
    end
  end

  return node
end

local function visual_select(range)
  assert(type(range) == 'table')
  local srow, scol, erow, ecol = Range.unpack4(range)
  local cursor_other_end_of_visual = false

  if vim.fn.mode() == 'v' then
    local vcol, vrow = vim.fn.col('v'), vim.fn.line('v')
    local ccol, cline = vim.fn.col('.'), vim.fn.line('.')
    if vrow > cline or (vrow == cline and vcol > ccol) then
      cursor_other_end_of_visual = true
    end
  end

  vim.api.nvim_win_set_cursor(0, { srow + 1, scol })
  vim.api.nvim_feedkeys(vim.keycode('<C-\\><C-n>v'), 'nx', true)

  if not pcall(vim.api.nvim_win_set_cursor, 0, { erow + 1, ecol - 1 }) then
    vim.api.nvim_win_set_cursor(0, { erow, #vim.fn.getline(erow) })
  end

  if cursor_other_end_of_visual then
    vim.api.nvim_feedkeys('o', 'nx', true)
  end
end

--- @return Range4
local function get_selection()
  local pos1 = vim.fn.getpos('v')
  local pos2 = vim.fn.getpos('.')
  if pos1[2] > pos2[2] or (pos1[2] == pos2[2] and pos1[3] > pos2[3]) then
    --- @type Range4,Range4
    pos1, pos2 = pos2, pos1
  end
  local range = { pos1[2] - 1, pos1[3] - 1, pos2[2] - 1, pos2[3] }

  if range[4] == #vim.fn.getline(range[3] + 1) + 1 then
    range[3] = range[3] + 1
    range[4] = 0
  end

  return range
end

local function get_parent_from_range(range)
  local node, parent_chain = get_node(range)

  if node == false then
    return (assert(parent_chain[1]))
  end

  if not node then
    return
  end

  if not range_is_same(range, node_range(node)) then
    return node
  end

  node = node_normalize_up(node, parent_chain)

  local parent = node_get_parent_no_normalize(node, parent_chain)

  if parent then
    if
      history.bufnr ~= vim.api.nvim_get_current_buf()
      or history.changedtick ~= vim.b.changedtick
      or history.current_node_id ~= node_id(node)
    then
      history = {
        bufnr = vim.api.nvim_get_current_buf(),
        changedtick = vim.b.changedtick,
      }
    end
    table.insert(history, node)
    history.current_node_id = node_id(parent)

    return parent
  end
end

local function get_child_from_range(range)
  local node, alternative_child_nodes = get_node(range)

  if node == false then
    return (assert(alternative_child_nodes[1]))
  end

  if not node then
    return
  end

  node = node_normalize_down(node)

  if not range_is_same(range, node_range(node)) then
    history = {}

    local smallest_node = get_node_contained_in_range(range, node)
    if smallest_node then
      return smallest_node
    end

    return node
  end

  if
    history.bufnr == vim.api.nvim_get_current_buf()
    and history.changedtick == vim.b.changedtick
    and history.current_node_id == node_id(node)
  then
    --- @type vim.treesitter.select.node
    local child = table.remove(history)
    if child then
      history.current_node_id = node_id(child)

      return child
    end
  end
  history = {}

  for _, child in ipairs(node_get_children_no_normalize(node)) do
    if not node_is_size_0(child) then
      return child
    end
  end

  return node
end

--- @param prev boolean
local function get_sibling_from_range(range, prev)
  local node, parent_chain = get_node(range)
  if not node then
    return
  end

  node = node_normalize_up(node, parent_chain)
  local parent = node_get_parent_no_normalize(node, parent_chain)
  if not parent then
    return
  end

  local siblings = node_get_children_no_normalize(parent)

  --- @type integer?
  local idx
  for n, child in ipairs(siblings) do
    if node_id(child) == node_id(node) then
      idx = n + (prev and -1 or 1)
      break
    end
  end
  assert(idx)

  while siblings[idx] and node_is_size_0(siblings[idx]) do
    idx = idx + (prev and -1 or 1)
  end

  if siblings[idx] then
    return siblings[idx]
  end
end

local function get_next_from_range(range)
  return get_sibling_from_range(range, false)
end

local function get_prev_from_range(range)
  return get_sibling_from_range(range, true)
end

--- @param count integer
--- @param fn fun(range: Range4): vim.treesitter.select.node
local function repeate_apply_range(count, fn)
  local range = get_selection()

  for _ = 1, count or 1 do
    local node = fn(range)

    if not node then
      break
    end

    range = node_range(node)
  end

  if range and count ~= 0 then
    visual_select(range)
  end
end

--- @param count integer
function M.select_parent(count)
  repeate_apply_range(count, get_parent_from_range)
end

--- @param count integer
function M.select_child(count)
  repeate_apply_range(count, get_child_from_range)
end

--- @param count integer
function M.select_next(count)
  repeate_apply_range(count, get_next_from_range)
end

--- @param count integer
function M.select_prev(count)
  repeate_apply_range(count, get_prev_from_range)
end

return M
