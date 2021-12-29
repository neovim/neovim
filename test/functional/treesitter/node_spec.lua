local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local exec_lua = helpers.exec_lua
local insert = helpers.insert
local pending_c_parser = helpers.pending_c_parser

before_each(clear)

local function lua_eval(lua_expr)
  return exec_lua("return " .. lua_expr)
end

describe('treesitter node API', function()
  clear()

  if pending_c_parser(pending) then
    return
  end

  it('can move between siblings', function()
    insert([[
      int main(int x, int y, int z) {
        return x + y * z
      }
    ]])

    exec_lua([[
      query = require"vim.treesitter.query"
      parser = vim.treesitter.get_parser(0, "c")
      tree = parser:parse()[1]
      root = tree:root()
      lang = vim.treesitter.inspect_language('c')

      function node_text(node)
        return query.get_node_text(node, 0)
      end
    ]])

    exec_lua 'node = root:descendant_for_range(0, 11, 0, 16)'
    eq('int x', lua_eval('node_text(node)'))

    exec_lua 'node = node:next_sibling()'
    eq(',', lua_eval('node_text(node)'))

    exec_lua 'node = node:next_sibling()'
    eq('int y', lua_eval('node_text(node)'))

    exec_lua 'node = node:prev_sibling()'
    eq(',', lua_eval('node_text(node)'))

    exec_lua 'node = node:prev_sibling()'
    eq('int x', lua_eval('node_text(node)'))

    exec_lua 'node = node:next_named_sibling()'
    eq('int y', lua_eval('node_text(node)'))

    exec_lua 'node = node:prev_named_sibling()'
    eq('int x', lua_eval('node_text(node)'))
  end)
end)
