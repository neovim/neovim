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
    exec_lua(function()
      vim.treesitter.start(0, 'lua')
      vim.treesitter.get_node():tree()
      vim.treesitter.get_node():tree()
      collectgarbage()
    end)
    assert_alive()
  end)

  it('double free tree 2', function()
    exec_lua(function()
      local parser = vim.treesitter.get_parser(0, 'c')
      local x = parser:parse()[1]:root():tree()
      vim.api.nvim_buf_set_text(0, 0, 0, 0, 0, { 'y' })
      parser:parse()
      vim.api.nvim_buf_set_text(0, 0, 0, 0, 1, { 'z' })
      parser:parse()
      collectgarbage()
      x:root()
    end)
    assert_alive()
  end)

  it('get_node() with lang given', function()
    -- this buffer doesn't have filetype set!
    insert('local foo = function() end')
    exec_lua(function()
      _G.node = vim.treesitter.get_node({
        bufnr = 0,
        pos = { 0, 6 }, -- on "foo"
        lang = 'lua',
      })
    end)
    eq('foo', lua_eval('vim.treesitter.get_node_text(node, 0)'))
    eq('identifier', lua_eval('node:type()'))
  end)

  it('get_node() with anonymous nodes included', function()
    insert([[print('test')]])

    exec_lua(function()
      _G.parser = vim.treesitter.get_parser(0, 'lua')
      _G.tree = _G.parser:parse()[1]
      _G.node = vim.treesitter.get_node({
        bufnr = 0,
        pos = { 0, 6 }, -- on the first apostrophe
        include_anonymous = true,
      })
    end)

    eq("'", lua_eval('node:type()'))
    eq(false, lua_eval('node:named()'))
  end)

  it('can move between siblings', function()
    insert([[
      int main(int x, int y, int z) {
        return x + y * z
      }
    ]])

    exec_lua(function()
      local parser = vim.treesitter.get_parser(0, 'c')
      local tree = parser:parse()[1]
      _G.root = tree:root()
      vim.treesitter.language.inspect('c')

      function _G.node_text(node)
        return vim.treesitter.get_node_text(node, 0)
      end
    end)

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

    local len = exec_lua(function()
      local tree = vim.treesitter.get_parser(0, 'c'):parse()[1]
      local node = assert(tree:root():child(0))
      _G.children = node:named_children()

      return #_G.children
    end)

    eq(3, len)
    eq('<node compound_statement>', lua_eval('tostring(children[3])'))
  end)

  it('can retrieve the tree root given a node', function()
    insert([[
      int main() {
        int x = 3;
      }]])

    exec_lua(function()
      local tree = vim.treesitter.get_parser(0, 'c'):parse()[1]
      _G.root = tree:root()
      _G.node = _G.root:child(0):child(2)
    end)

    eq(lua_eval('tostring(root)'), lua_eval('tostring(node:root())'))
  end)

  it('can compute the byte length of a node', function()
    insert([[
      int main() {
        int x = 3;
      }]])

    exec_lua(function()
      local tree = vim.treesitter.get_parser(0, 'c'):parse()[1]
      _G.root = tree:root()
      _G.child = _G.root:child(0):child(0)
    end)

    eq(28, lua_eval('root:byte_length()'))
    eq(3, lua_eval('child:byte_length()'))
  end)

  it('child_containing_descendant() works', function()
    insert([[
      int main() {
        int x = 3;
      }]])

    exec_lua(function()
      local tree = vim.treesitter.get_parser(0, 'c'):parse()[1]
      _G.root = tree:root()
      _G.main = _G.root:child(0)
      _G.body = _G.main:child(2)
      _G.statement = _G.body:child(1)
      _G.declarator = _G.statement:child(1)
      _G.value = _G.declarator:child(1)
    end)

    eq(lua_eval('main:type()'), lua_eval('root:child_containing_descendant(value):type()'))
    eq(lua_eval('body:type()'), lua_eval('main:child_containing_descendant(value):type()'))
    eq(lua_eval('statement:type()'), lua_eval('body:child_containing_descendant(value):type()'))
    eq(
      lua_eval('declarator:type()'),
      lua_eval('statement:child_containing_descendant(value):type()')
    )
    eq(vim.NIL, lua_eval('declarator:child_containing_descendant(value)'))
  end)

  it('child_with_descendant() works', function()
    insert([[
      int main() {
        int x = 3;
      }]])

    exec_lua(function()
      local tree = vim.treesitter.get_parser(0, 'c'):parse()[1]
      _G.root = assert(tree:root())
      _G.main = assert(_G.root:child(0))
      _G.body = assert(_G.main:child(2))
      _G.statement = assert(_G.body:child(1))
      _G.declarator = assert(_G.statement:child(1))
      _G.value = assert(_G.declarator:child(1))
    end)

    eq(lua_eval('main:type()'), lua_eval('root:child_with_descendant(value):type()'))
    eq(lua_eval('body:type()'), lua_eval('main:child_with_descendant(value):type()'))
    eq(lua_eval('statement:type()'), lua_eval('body:child_with_descendant(value):type()'))
    eq(lua_eval('declarator:type()'), lua_eval('statement:child_with_descendant(value):type()'))
    eq(lua_eval('value:type()'), lua_eval('declarator:child_with_descendant(value):type()'))
    eq(vim.NIL, lua_eval('value:child_with_descendant(value)'))
  end)
end)
