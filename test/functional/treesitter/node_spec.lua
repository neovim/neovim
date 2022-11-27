local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local exec_lua = helpers.exec_lua
local insert = helpers.insert

before_each(clear)

local function lua_eval(lua_expr)
  return exec_lua("return " .. lua_expr)
end

describe('treesitter node API', function()
  clear()

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

  it('can retrieve the children of a node', function()
    insert([[
      int main() {
        int x = 3;
      }]])

    local len = exec_lua([[
      tree = vim.treesitter.get_parser(0, "c"):parse()[1]
      node = tree:root():child(0)
      children = node:named_children()

      return #children
    ]])

    eq(3, len)
    eq('<node compound_statement>', lua_eval('tostring(children[3])'))
  end)

  it('can retrieve the tree root given a node', function()
    insert([[
      int main() {
        int x = 3;
      }]])

    exec_lua([[
      tree = vim.treesitter.get_parser(0, "c"):parse()[1]
      root = tree:root()
      node = root:child(0):child(2)
    ]])

    eq(lua_eval('tostring(root)'), lua_eval('tostring(node:root())'))
  end)

  it('can compute the byte length of a node', function()
    insert([[
      int main() {
        int x = 3;
      }]])

    exec_lua([[
      tree = vim.treesitter.get_parser(0, "c"):parse()[1]
      root = tree:root()
      child = root:child(0):child(0)
    ]])

    eq(28, lua_eval('root:byte_length()'))
    eq(3, lua_eval('child:byte_length()'))
  end)
end)
