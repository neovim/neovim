-- Test suite for testing interactions with API bindings
local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local insert = helpers.insert
local exec_lua = helpers.exec_lua
local iswin = helpers.iswin
local feed = helpers.feed

before_each(clear)

describe('tree-sitter API', function()
  -- error tests not requiring a parser library
  it('handles basic errors', function()
    --eq({false, 'Error executing lua: vim.schedule: expected function'},
    --   meth_pcall(meths.execute_lua, "parser = vim.treesitter.create_parser(0, 'nosuchlang')", {}))



  end)

  local ts_path = os.getenv("TREE_SITTER_DIR")

  describe('with C parser', function()
    if ts_path == nil then
      it("works", function() pending("TREE_SITTER_PATH not set, skipping tree-sitter parser tests") end)
      return
    end

    before_each(function()
      -- TODO the .so/.dylib/.dll thingie
      local path = ts_path .. '/bin/c'..(iswin() and '.dll' or '.so')
      exec_lua([[
        local path = ...
        vim.treesitter.add_language(path,'c')

      ]], path)
    end)

    it('parses buffer', function()
      insert([[
        int main() {
          int x = 3;
        }]])

      exec_lua([[
        parser = vim.treesitter.get_parser(0, "c")
        tree = parser:parse()
        root = tree:root()
      ]])

      eq("<tree>", exec_lua("return tostring(tree)"))
      eq("<node translation_unit>", exec_lua("return tostring(root)"))
      eq({0,0,3,0}, exec_lua("return {root:range()}"))

      eq(1, exec_lua("return root:child_count()"))
      exec_lua("child = root:child(0)")
      eq("<node function_definition>", exec_lua("return tostring(child)"))
      eq({0,0,2,1}, exec_lua("return {child:range()}"))

      exec_lua("descendant = root:descendant_for_range(1,2,1,12)")
      eq("<node declaration>", exec_lua("return tostring(descendant)"))
      eq({1,2,1,12}, exec_lua("return {descendant:range()}"))
      eq("(declaration (primitive_type) (init_declarator (identifier) (number_literal)))", exec_lua("return descendant:sexpr()"))

      feed("2G7|ay")
      exec_lua([[
        tree2 = parser:parse()
        root2 = tree2:root()
        descendant2 = root2:descendant_for_range(1,2,1,13)
      ]])
      eq(false, exec_lua("return tree2 == tree1"))
      eq("<node declaration>", exec_lua("return tostring(descendant2)"))
      eq({1,2,1,13}, exec_lua("return {descendant2:range()}"))

      -- orginal tree did not change
      eq({1,2,1,12}, exec_lua("return {descendant:range()}"))

      -- unchanged buffer: return the same tree
      eq(true, exec_lua("return parser:parse() == tree2"))
    end)

  end)
end)

