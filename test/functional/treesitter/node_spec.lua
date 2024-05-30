local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local eq = t.eq
local exec_lua = n.exec_lua
local insert = n.insert
local assert_alive = n.assert_alive

before_each(clear)

local function lua_eval(lua_expr)
  return exec_lua('return ' .. lua_expr)
end

describe('treesitter node API', function()
  clear()

  it('double free tree', function()
    insert('F')
    exec_lua([[
      vim.treesitter.start(0, 'lua')
      vim.treesitter.get_node():tree()
      vim.treesitter.get_node():tree()
      collectgarbage()
    ]])
    assert_alive()
  end)

  it('double free tree 2', function()
    exec_lua([[
      parser = vim.treesitter.get_parser(0, "c")
      local x = parser:parse()[1]:root():tree()
      vim.api.nvim_buf_set_text(0, 0,0, 0,0, {'y'})
      parser:parse()
      vim.api.nvim_buf_set_text(0, 0,0, 0,1, {'z'})
      parser:parse()
      collectgarbage()
      x:root()
    ]])
    assert_alive()
  end)

  it('get_node() with lang given', function()
    -- this buffer doesn't have filetype set!
    insert('local foo = function() end')
    exec_lua([[
      node = vim.treesitter.get_node({
        bufnr = 0,
        pos = { 0, 6 },  -- on "foo"
        lang = 'lua',
      })
    ]])
    eq('foo', lua_eval('vim.treesitter.get_node_text(node, 0)'))
    eq('identifier', lua_eval('node:type()'))
  end)

  it('can move between siblings', function()
    insert([[
      int main(int x, int y, int z) {
        return x + y * z
      }
    ]])

    exec_lua([[
      parser = vim.treesitter.get_parser(0, "c")
      tree = parser:parse()[1]
      root = tree:root()
      lang = vim.treesitter.language.inspect('c')

      function node_text(node)
        return vim.treesitter.get_node_text(node, 0)
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

  it('child_containing_descendant() works', function()
    insert([[
      int main() {
        int x = 3;
      }]])

    exec_lua([[
      tree = vim.treesitter.get_parser(0, "c"):parse()[1]
      root = tree:root()
      main = root:child(0)
      body = main:child(2)
      statement = body:child(1)
      declarator = statement:child(1)
      value = declarator:child(1)
    ]])

    eq(lua_eval('main:type()'), lua_eval('root:child_containing_descendant(value):type()'))
    eq(lua_eval('body:type()'), lua_eval('main:child_containing_descendant(value):type()'))
    eq(lua_eval('statement:type()'), lua_eval('body:child_containing_descendant(value):type()'))
    eq(
      lua_eval('declarator:type()'),
      lua_eval('statement:child_containing_descendant(value):type()')
    )
    eq(vim.NIL, lua_eval('declarator:child_containing_descendant(value)'))
  end)
end)
