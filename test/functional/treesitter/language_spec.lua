local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local exec_lua = helpers.exec_lua
local pcall_err = helpers.pcall_err
local matches = helpers.matches
local pending_c_parser = helpers.pending_c_parser

before_each(clear)

describe('treesitter API', function()
  -- error tests not requiring a parser library
  it('handles missing language', function()
    eq("Error executing lua: .../language.lua:0: no parser for 'borklang' language, see :help treesitter-parsers",
       pcall_err(exec_lua, "parser = vim.treesitter.get_parser(0, 'borklang')"))

    -- actual message depends on platform
    matches("Error executing lua: Failed to load parser: uv_dlopen: .+",
       pcall_err(exec_lua, "parser = vim.treesitter.require_language('borklang', 'borkbork.so')"))

    -- Should not throw an error when silent
    eq(false, exec_lua("return vim.treesitter.require_language('borklang', nil, true)"))
    eq(false, exec_lua("return vim.treesitter.require_language('borklang', 'borkbork.so', true)"))

    eq("Error executing lua: .../language.lua:0: no parser for 'borklang' language, see :help treesitter-parsers",
       pcall_err(exec_lua, "parser = vim.treesitter.inspect_language('borklang')"))
  end)

  it('inspects language', function()
    if pending_c_parser(pending) then return end

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

    eq({fields=true, symbols=true, _abi_version=true}, keys)

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

