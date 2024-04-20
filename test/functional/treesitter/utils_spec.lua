local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local insert = n.insert
local eq = t.eq
local exec_lua = n.exec_lua

before_each(clear)

describe('treesitter utils', function()
  before_each(clear)

  it('can find an ancestor', function()
    insert([[
      int main() {
        int x = 3;
      }]])

    exec_lua([[
      parser = vim.treesitter.get_parser(0, "c")
      tree = parser:parse()[1]
      root = tree:root()
      ancestor = root:child(0)
      child = ancestor:child(0)
    ]])

    eq(true, exec_lua('return vim.treesitter.is_ancestor(ancestor, child)'))
    eq(false, exec_lua('return vim.treesitter.is_ancestor(child, ancestor)'))
  end)

  it('can detect if a position is contained in a node', function()
    exec_lua([[
      node = {
        range = function()
          return 0, 4, 0, 8
        end,
      }
    ]])

    eq(false, exec_lua('return vim.treesitter.is_in_node_range(node, 0, 3)'))
    for i = 4, 7 do
      eq(true, exec_lua('return vim.treesitter.is_in_node_range(node, 0, ...)', i))
    end
    -- End column exclusive
    eq(false, exec_lua('return vim.treesitter.is_in_node_range(node, 0, 8)'))
  end)
end)
