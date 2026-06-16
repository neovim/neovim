local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local command = n.command
local eq = t.eq
local exec_lua = n.exec_lua
local insert = n.insert
local skip = t.skip

local lua_text = [[
local M = {}

-- returns the sum of two numbers
local function add(a, b)
  return a + b
end

M.add = add
return M
]]

describe('treesitter WASM parser', function()
  before_each(clear)

  it('lua WASM parser produces same highlight captures as native parser', function()
    skip(
      exec_lua('return vim._ts_add_language_from_wasm == nil'),
      'N/A ENABLE_WASMTIME not enabled'
    )

    local wasm_files = exec_lua(function()
      return vim.api.nvim_get_runtime_file('parser/lua.wasm', true)
    end)
    assert(
      #wasm_files > 0,
      'lua.wasm not found in runtimepath (rebuild with ENABLE_WASMTIME=ON USE_BUNDLED_TS_PARSERS=ON)'
    )

    local wasm_path = wasm_files[1]

    local query_str = exec_lua(function()
      local files = vim.api.nvim_get_runtime_file('queries/lua/highlights.scm', false)
      assert(#files > 0, 'queries/lua/highlights.scm not found')
      local f = assert(io.open(files[1]))
      local s = f:read('*a')
      f:close()
      return s
    end)

    -- Buffer 1: parse with the native lua parser.
    insert(lua_text)
    local native_captures = exec_lua(function(qstr)
      local query = vim.treesitter.query.parse('lua', qstr)
      local parser = vim.treesitter.get_parser(0, 'lua')
      local tree = parser:parse()[1]
      local result = {}
      for id, node in query:iter_captures(tree:root(), 0) do
        local r = { node:range() }
        table.insert(result, { query.captures[id], r[1], r[2], r[3], r[4] })
      end
      return result
    end, query_str)

    -- Buffer 2: same content, but the lua language loaded from WASM.
    command('new')
    insert(lua_text)
    local wasm_captures = exec_lua(function(path, qstr)
      -- Remove the native registration so the WASM one can take its place.
      vim._ts_remove_language('lua')
      vim._ts_add_language_from_wasm(path, 'lua')
      local query = vim.treesitter.query.parse('lua', qstr)
      local parser = vim.treesitter.get_parser(0, 'lua')
      local tree = parser:parse()[1]
      local result = {}
      for id, node in query:iter_captures(tree:root(), 0) do
        local r = { node:range() }
        table.insert(result, { query.captures[id], r[1], r[2], r[3], r[4] })
      end
      return result
    end, wasm_path, query_str)

    eq(native_captures, wasm_captures)
  end)
end)
