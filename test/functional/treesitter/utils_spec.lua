local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local insert = helpers.insert
local eq = helpers.eq
local exec_lua = helpers.exec_lua
local pending_c_parser = helpers.pending_c_parser

before_each(clear)

describe('treesitter utils', function()
  before_each(clear)

  it('can find an ancestor', function()
    if pending_c_parser(pending) then return end

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
end)
