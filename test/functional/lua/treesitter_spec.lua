-- Test suite for testing interactions with API bindings
local helpers = require('test.functional.helpers')(after_each)

local meths = helpers.meths
local clear = helpers.clear
local eq = helpers.eq
local insert = helpers.insert
local meth_pcall = helpers.meth_pcall
local exec_lua = helpers.exec_lua
local iswin = helpers.iswin

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
        parser = vim.treesitter.create_parser(0, "c")
        tree = parser:parse_tree()
        root = tree:root()
      ]])

      --eq("<parser>", exec_lua("return tostring(parser)"))
      eq("<tree>", exec_lua("return tostring(tree)"))
      eq("<node translation_unit>", exec_lua("return tostring(root)"))
      eq({0,0,3,0}, exec_lua("return {root:range()}"))

      eq(1, exec_lua("return root:child_count()"))
      exec_lua("child = root:child(0)")
      eq("<node function_definition>", exec_lua("return tostring(child)"))
      eq({0,0,2,1}, exec_lua("return {child:range()}"))
    end)

  end)
end)

