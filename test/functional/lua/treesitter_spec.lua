-- Test suite for testing interactions with API bindings
local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local insert = helpers.insert
local exec_lua = helpers.exec_lua
local iswin = helpers.iswin
local feed = helpers.feed
local pcall_err = helpers.pcall_err
local matches = helpers.matches

before_each(clear)

describe('treesitter API', function()
  -- error tests not requiring a parser library
  it('handles missing language', function()
      local path_pat = 'Error executing lua: '..(iswin() and '.+\\vim\\' or '.+/vim/')

    matches(path_pat..'treesitter.lua:39: no such language: borklang',
       pcall_err(exec_lua, "parser = vim.treesitter.create_parser(0, 'borklang')"))

    -- actual message depends on platform
    matches('Error executing lua: Failed to load parser: uv_dlopen: .+',
       pcall_err(exec_lua, "parser = vim.treesitter.add_language('borkbork.so', 'borklang')"))

    eq('Error executing lua: [string "<nvim>"]:1: no such language: borklang',
       pcall_err(exec_lua, "parser = vim.treesitter.inspect_language('borklang')"))
  end)

  local ts_path = os.getenv("TREE_SITTER_DIR")

  describe('with C parser', function()
    if ts_path == nil then
      it("works", function() pending("TREE_SITTER_PATH not set, skipping treesitter parser tests") end)
      return
    end

    before_each(function()
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
        lang = vim.treesitter.inspect_language('c')
      ]])

      eq("<tree>", exec_lua("return tostring(tree)"))
      eq("<node translation_unit>", exec_lua("return tostring(root)"))
      eq({0,0,3,0}, exec_lua("return {root:range()}"))

      eq(1, exec_lua("return root:child_count()"))
      exec_lua("child = root:child(0)")
      eq("<node function_definition>", exec_lua("return tostring(child)"))
      eq({0,0,2,1}, exec_lua("return {child:range()}"))

      eq("function_definition", exec_lua("return child:type()"))
      eq(true, exec_lua("return child:named()"))
      eq("number", type(exec_lua("return child:symbol()")))
      eq({'function_definition', true}, exec_lua("return lang.symbols[child:symbol()]"))

      exec_lua("anon = root:descendant_for_range(0,8,0,9)")
      eq("(", exec_lua("return anon:type()"))
      eq(false, exec_lua("return anon:named()"))
      eq("number", type(exec_lua("return anon:symbol()")))
      eq({'(', false}, exec_lua("return lang.symbols[anon:symbol()]"))

      exec_lua("descendant = root:descendant_for_range(1,2,1,12)")
      eq("<node declaration>", exec_lua("return tostring(descendant)"))
      eq({1,2,1,12}, exec_lua("return {descendant:range()}"))
      eq("(declaration type: (primitive_type) declarator: (init_declarator declarator: (identifier) value: (number_literal)))", exec_lua("return descendant:sexpr()"))

      eq(true, exec_lua("return child == child"))
      -- separate lua object, but represents same node
      eq(true, exec_lua("return child == root:child(0)"))
      eq(false, exec_lua("return child == descendant2"))
      eq(false, exec_lua("return child == nil"))
      eq(false, exec_lua("return child == tree"))

      feed("2G7|ay")
      exec_lua([[
        tree2 = parser:parse()
        root2 = tree2:root()
        descendant2 = root2:descendant_for_range(1,2,1,13)
      ]])
      eq(false, exec_lua("return tree2 == tree1"))
      eq(false, exec_lua("return root2 == root"))
      eq("<node declaration>", exec_lua("return tostring(descendant2)"))
      eq({1,2,1,13}, exec_lua("return {descendant2:range()}"))

      -- orginal tree did not change
      eq({1,2,1,12}, exec_lua("return {descendant:range()}"))

      -- unchanged buffer: return the same tree
      eq(true, exec_lua("return parser:parse() == tree2"))
    end)

    it('inspects language', function()
        local keys, fields, symbols = unpack(exec_lua([[
          local lang = vim.treesitter.inspect_language('c')
          local keys, symbols = {}, {}
          for k,_ in pairs(lang) do
            keys[k] = true
          end

          -- symbols array can have "holes" and is thus not a valid msgpack array
          -- but we don't care about the numbers here (checked in the parser test)
          for _, v in pairs(lang.symbols) do
            table.insert(symbols, v)
          end
          return {keys, lang.fields, symbols}
        ]]))

        eq({fields=true, symbols=true}, keys)

        local fset = {}
        for _,f in pairs(fields) do
          eq("string", type(f))
          fset[f] = true
        end
        eq(true, fset["directive"])
        eq(true, fset["initializer"])

        local has_named, has_anonymous
        for _,s in pairs(symbols) do
          eq("string", type(s[1]))
          eq("boolean", type(s[2]))
          if s[1] == "for_statement" and s[2] == true then
            has_named = true
          elseif s[1] == "|=" and s[2] == false then
            has_anonymous = true
          end
        end
        eq({true,true}, {has_named,has_anonymous})
    end)
  end)
end)
