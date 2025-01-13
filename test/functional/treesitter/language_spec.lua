local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local eq = t.eq
local command = n.command
local exec_lua = n.exec_lua
local pcall_err = t.pcall_err
local matches = t.matches
local insert = n.insert
local NIL = vim.NIL

before_each(clear)

describe('treesitter language API', function()
  -- error tests not requiring a parser library
  it('handles missing language', function()
    eq(
      '.../treesitter.lua:0: Parser could not be created for buffer 1 and language "borklang"',
      pcall_err(exec_lua, "parser = vim.treesitter.get_parser(0, 'borklang')")
    )

    eq(NIL, exec_lua("return vim.treesitter.get_parser(0, 'borklang', { error = false })"))

    -- actual message depends on platform
    matches(
      "Failed to load parser for language 'borklang': uv_dlopen: .+",
      pcall_err(
        exec_lua,
        "parser = vim.treesitter.language.add('borklang', { path = 'borkbork.so' })"
      )
    )

    eq(NIL, exec_lua("return vim.treesitter.language.add('borklang')"))

    eq(
      false,
      exec_lua("return pcall(vim.treesitter.language.add, 'borklang', { path = 'borkbork.so' })")
    )

    matches(
      'Failed to load parser: uv_dlsym: .+',
      pcall_err(exec_lua, 'vim.treesitter.language.add("c", { symbol_name = "borklang" })')
    )
  end)

  it('does not load parser for invalid language name', function()
    eq(NIL, exec_lua('vim.treesitter.language.add("/foo/")'))
  end)

  it('inspects language', function()
    local keys, fields, symbols = unpack(exec_lua(function()
      local lang = vim.treesitter.language.inspect('c')
      local keys = {}
      for k, v in pairs(lang) do
        if type(v) == 'boolean' then
          keys[k] = v
        else
          keys[k] = true
        end
      end

      return { keys, lang.fields, lang.symbols }
    end))

    eq({ fields = true, symbols = true, _abi_version = true, _wasm = false }, keys)

    local fset = {}
    for _, f in pairs(fields) do
      eq('string', type(f))
      fset[f] = true
    end
    eq(true, fset['directive'])
    eq(true, fset['initializer'])

    local has_named, has_anonymous, has_supertype
    for symbol, named in pairs(symbols) do
      eq('string', type(symbol))
      eq('boolean', type(named))
      if symbol == 'for_statement' and named == true then
        has_named = true
      elseif symbol == '"|="' and named == false then
        has_anonymous = true
      elseif symbol == 'statement' and named == true then
        has_supertype = true
      end
    end
    eq(
      { has_named = true, has_anonymous = true, has_supertype = true },
      { has_named = has_named, has_anonymous = has_anonymous, has_supertype = has_supertype }
    )
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
        '.../treesitter.lua:0: Parser could not be created for buffer 1 and language "borklang"',
        pcall_err(exec_lua, "new_parser = vim.treesitter.get_parser(0, 'borklang')")
      )
      eq(NIL, exec_lua("return vim.treesitter.get_parser(0, 'borklang', { error = false })"))
    end
  )

  it('retrieve the tree given a range', function()
    insert([[
      int main() {
        int x = 3;
      }]])

    eq(
      '<node translation_unit>',
      exec_lua(function()
        local langtree = vim.treesitter.get_parser(0, 'c')
        langtree:parse()
        local tree = langtree:tree_for_range({ 1, 3, 1, 3 })
        return tostring(tree:root())
      end)
    )
  end)

  it('retrieve the tree given a range when range is out of bounds relative to buffer', function()
    insert([[
      int main() {
        int x = 3;
      }]])

    eq(
      '<node translation_unit>',
      exec_lua(function()
        local langtree = vim.treesitter.get_parser(0, 'c')
        langtree:parse()
        local tree = langtree:tree_for_range({ 10, 10, 10, 10 })
        return tostring(tree:root())
      end)
    )
  end)

  it('retrieve the node given a range', function()
    insert([[
      int main() {
        int x = 3;
      }]])

    eq(
      '<node primitive_type>',
      exec_lua(function()
        local langtree = vim.treesitter.get_parser(0, 'c')
        langtree:parse()
        local node = langtree:named_node_for_range({ 1, 3, 1, 3 })
        return tostring(node)
      end)
    )
  end)

  it('retrieve an anonymous node given a range', function()
    insert([[vim.fn.input()]])

    exec_lua(function()
      _G.langtree = vim.treesitter.get_parser(0, 'lua')
      _G.langtree:parse()
      _G.node = _G.langtree:node_for_range({ 0, 3, 0, 3 })
    end)

    eq('.', exec_lua('return node:type()'))
  end)
end)
