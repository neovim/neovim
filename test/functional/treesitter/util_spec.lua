local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local insert = n.insert
local eq = t.eq
local exec_lua = n.exec_lua

before_each(clear)

describe('treesitter utils', function()
  it('can find an ancestor', function()
    insert([[
      int main() {
        int x = 3;
      }]])

    exec_lua(function()
      local parser = vim.treesitter.get_parser(0, 'c')
      local tree = parser:parse()[1]
      local root = tree:root()
      _G.ancestor = assert(root:child(0))
      _G.child = assert(_G.ancestor:named_child(1))
      _G.child_sibling = assert(_G.ancestor:named_child(2))
      _G.grandchild = assert(_G.child:named_child(0))
    end)

    eq(true, exec_lua('return vim.treesitter.is_ancestor(_G.ancestor, _G.child)'))
    eq(true, exec_lua('return vim.treesitter.is_ancestor(_G.ancestor, _G.grandchild)'))
    eq(false, exec_lua('return vim.treesitter.is_ancestor(_G.child, _G.ancestor)'))
    eq(false, exec_lua('return vim.treesitter.is_ancestor(_G.child, _G.child_sibling)'))
  end)

  it('can detect if a position is contained in a node', function()
    exec_lua(function()
      _G.node = {
        range = function()
          return 0, 4, 0, 8
        end,
      }
    end)

    eq(false, exec_lua('return vim.treesitter.is_in_node_range(node, 0, 3)'))
    for i = 4, 7 do
      eq(true, exec_lua('return vim.treesitter.is_in_node_range(node, 0, ...)', i))
    end
    -- End column exclusive
    eq(false, exec_lua('return vim.treesitter.is_in_node_range(node, 0, 8)'))
  end)
end)
