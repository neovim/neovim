local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local eq = t.eq
local command = n.command
local exec_lua = n.exec_lua
local pcall_err = t.pcall_err
local matches = t.matches
local insert = n.insert

before_each(clear)

describe('treesitter language API', function()
  -- error tests not requiring a parser library
  it('handles missing language', function()
    eq(
      ".../language.lua:0: no parser for 'borklang' language, see :help treesitter-parsers",
      pcall_err(exec_lua, "parser = vim.treesitter.get_parser(0, 'borklang')")
    )

    -- actual message depends on platform
    matches(
      "Failed to load parser for language 'borklang': uv_dlopen: .+",
      pcall_err(
        exec_lua,
        "parser = vim.treesitter.language.add('borklang', { path = 'borkbork.so' })"
      )
    )

    eq(false, exec_lua("return pcall(vim.treesitter.language.add, 'borklang')"))

    eq(
      false,
      exec_lua("return pcall(vim.treesitter.language.add, 'borklang', { path = 'borkbork.so' })")
    )

    eq(
      ".../language.lua:0: no parser for 'borklang' language, see :help treesitter-parsers",
      pcall_err(exec_lua, "parser = vim.treesitter.language.inspect('borklang')")
    )

    matches(
      'Failed to load parser: uv_dlsym: .+',
      pcall_err(exec_lua, 'vim.treesitter.language.add("c", { symbol_name = "borklang" })')
    )
  end)

  it('shows error for invalid language name', function()
    eq(
      ".../language.lua:0: '/foo/' is not a valid language name",
      pcall_err(exec_lua, 'vim.treesitter.language.add("/foo/")')
    )
  end)

  it('inspects language', function()
    local keys, fields, symbols = unpack(exec_lua([[
      local lang = vim.treesitter.language.inspect('c')
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

    eq({ fields = true, symbols = true, _abi_version = true }, keys)

    local fset = {}
    for _, f in pairs(fields) do
      eq('string', type(f))
      fset[f] = true
    end
    eq(true, fset['directive'])
    eq(true, fset['initializer'])

    local has_named, has_anonymous
    for _, s in pairs(symbols) do
      eq('string', type(s[1]))
      eq('boolean', type(s[2]))
      if s[1] == 'for_statement' and s[2] == true then
        has_named = true
      elseif s[1] == '|=' and s[2] == false then
        has_anonymous = true
      end
    end
    eq({ true, true }, { has_named, has_anonymous })
  end)

  it(
    'checks if vim.treesitter.get_parser tries to create a new parser on filetype change',
    function()
      command('set filetype=c')
      -- Should not throw an error when filetype is c
      eq('c', exec_lua('return vim.treesitter.get_parser(0):lang()'))
      command('set filetype=borklang')
      -- Should throw an error when filetype changes to borklang
      eq(
        ".../language.lua:0: no parser for 'borklang' language, see :help treesitter-parsers",
        pcall_err(exec_lua, "new_parser = vim.treesitter.get_parser(0, 'borklang')")
      )
    end
  )

  it('retrieve the tree given a range', function()
    insert([[
      int main() {
        int x = 3;
      }]])

    exec_lua([[
      langtree = vim.treesitter.get_parser(0, "c")
      tree = langtree:tree_for_range({1, 3, 1, 3})
    ]])

    eq('<node translation_unit>', exec_lua('return tostring(tree:root())'))
  end)

  it('retrieve the tree given a range when range is out of bounds relative to buffer', function()
    insert([[
      int main() {
        int x = 3;
      }]])

    exec_lua([[
      langtree = vim.treesitter.get_parser(0, "c")
      tree = langtree:tree_for_range({10, 10, 10, 10})
    ]])

    eq('<node translation_unit>', exec_lua('return tostring(tree:root())'))
  end)

  it('retrieve the node given a range', function()
    insert([[
      int main() {
        int x = 3;
      }]])

    exec_lua([[
      langtree = vim.treesitter.get_parser(0, "c")
      node = langtree:named_node_for_range({1, 3, 1, 3})
    ]])

    eq('<node primitive_type>', exec_lua('return tostring(node)'))
  end)
end)
