local api = vim.api

local M = {}

---@class Playground
---@field ns number API namespace
---@field opts table Options table with the following keys:
---                  - anon (boolean): If true, display anonymous nodes
---                  - lang (boolean): If true, display the language alongside each node
---
---@class Node
---@field id number Node id
---@field text string Node text
---@field named boolean True if this is a named (non-anonymous) node
---@field depth number Depth of the node within the tree
---@field lnum number Beginning line number of this node in the source buffer
---@field col number Beginning column number of this node in the source buffer
---@field end_lnum number Final line number of this node in the source buffer
---@field end_col number Final column number of this node in the source buffer
---@field lang string Source language of this node

--- Traverse all child nodes starting at {node}.
---
--- This is a recursive function. The {depth} parameter indicates the current recursion level.
--- {lang} is a string indicating the language of the tree currently being traversed. Each traversed
--- node is added to {tree}. When recursion completes, {tree} is an array of all nodes in the order
--- they were visited.
---
--- {injections} is a table mapping node ids from the primary tree to language tree injections. Each
--- injected language has a series of trees nested within the primary language's tree, and the root
--- node of each of these trees is contained within a node in the primary tree. The {injections}
--- table maps nodes in the primary tree to root nodes of injected trees.
---
---@param node userdata Starting node to begin traversal |tsnode|
---@param depth number Current recursion depth
---@param lang string Language of the tree currently being traversed
---@param injections table Mapping of node ids to root nodes of injected language trees (see
---                        explanation above)
---@param tree Node[] Output table containing a list of tables each representing a node in the tree
---@private
local function traverse(node, depth, lang, injections, tree)
  local injection = injections[node:id()]
  if injection then
    traverse(injection.root, depth, injection.lang, injections, tree)
  end

  for child, field in node:iter_children() do
    local type = child:type()
    local lnum, col, end_lnum, end_col = child:range()
    local named = child:named()
    local text
    if named then
      if field then
        text = string.format('%s: (%s)', field, type)
      else
        text = string.format('(%s)', type)
      end
    else
      text = string.format('"%s"', type:gsub('\n', '\\n'))
    end

    table.insert(tree, {
      id = child:id(),
      text = text,
      named = named,
      depth = depth,
      lnum = lnum,
      col = col,
      end_lnum = end_lnum,
      end_col = end_col,
      lang = lang,
    })

    traverse(child, depth + 1, lang, injections, tree)
  end

  return tree
end

--- Create a new Playground object.
---
---@param bufnr number Source buffer number
---@param lang string|nil Language of source buffer
---
---@return Playground|nil
---@return string|nil Error message, if any
---
---@private
function M.new(self, bufnr, lang)
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr or 0, lang)
  if not ok then
    return nil, 'No parser available for the given buffer'
  end

  -- For each child tree (injected language), find the root of the tree and locate the node within
  -- the primary tree that contains that root. Add a mapping from the node in the primary tree to
  -- the root in the child tree to the {injections} table.
  local root = parser:parse()[1]:root()
  local injections = {}
  parser:for_each_child(function(child, lang_)
    child:for_each_tree(function(tree)
      local r = tree:root()
      local node = root:named_descendant_for_range(r:range())
      if node then
        injections[node:id()] = {
          lang = lang_,
          root = r,
        }
      end
    end)
  end)

  local nodes = traverse(root, 0, parser:lang(), injections, {})

  local named = {}
  for _, v in ipairs(nodes) do
    if v.named then
      named[#named + 1] = v
    end
  end

  local t = {
    ns = api.nvim_create_namespace(''),
    nodes = nodes,
    named = named,
    opts = {
      anon = false,
      lang = false,
    },
  }

  setmetatable(t, self)
  self.__index = self
  return t
end

--- Write the contents of this Playground into {bufnr}.
---
---@param bufnr number Buffer number to write into.
---@private
function M.draw(self, bufnr)
  vim.bo[bufnr].modifiable = true
  local lines = {}
  for _, item in self:iter() do
    lines[#lines + 1] = table.concat({
      string.rep(' ', item.depth),
      item.text,
      item.lnum == item.end_lnum
          and string.format(' [%d:%d-%d]', item.lnum + 1, item.col + 1, item.end_col)
        or string.format(
          ' [%d:%d-%d:%d]',
          item.lnum + 1,
          item.col + 1,
          item.end_lnum + 1,
          item.end_col
        ),
      self.opts.lang and string.format(' %s', item.lang) or '',
    })
  end
  api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].modifiable = false
end

--- Get node {i} from this Playground object.
---
--- The node number is dependent on whether or not anonymous nodes are displayed.
---
---@param i number Node number to get
---@return Node
---@private
function M.get(self, i)
  local t = self.opts.anon and self.nodes or self.named
  return t[i]
end

--- Iterate over all of the nodes in this Playground object.
---
---@return function Iterator over all nodes in this Playground
---@return table
---@return number
---@private
function M.iter(self)
  return ipairs(self.opts.anon and self.nodes or self.named)
end

return M
