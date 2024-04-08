-- Test suite for testing interactions with API bindings
local t = require('test.functional.testutil')(after_each)

local exec_lua = t.exec_lua
local command = t.command
local clear = t.clear
local eq = t.eq

describe('vim.loader', function()
  before_each(clear)

  it('can work in compatibility with --luamod-dev #27413', function()
    clear({ args = { '--luamod-dev' } })
    exec_lua [[
      vim.loader.enable()

      require("vim.fs")

      -- try to load other vim submodules as well (Nvim Lua stdlib)
      for key, _ in pairs(vim._submodules) do
        local modname = 'vim.' .. key   -- e.g. "vim.fs"

        local lhs = vim[key]
        local rhs = require(modname)
        assert(
          lhs == rhs,
          ('%s != require("%s"), %s != %s'):format(modname, modname, tostring(lhs), tostring(rhs))
        )
      end
    ]]
  end)

  it('handles changing files (#23027)', function()
    exec_lua [[
      vim.loader.enable()
    ]]

    local tmp = t.tmpname()
    command('edit ' .. tmp)

    eq(
      1,
      exec_lua(
        [[
      vim.api.nvim_buf_set_lines(0, 0, -1, true, {'_G.TEST=1'})
      vim.cmd.write()
      loadfile(...)()
      return _G.TEST
    ]],
        tmp
      )
    )

    -- fs latency
    vim.uv.sleep(10)

    eq(
      2,
      exec_lua(
        [[
      vim.api.nvim_buf_set_lines(0, 0, -1, true, {'_G.TEST=2'})
      vim.cmd.write()
      loadfile(...)()
      return _G.TEST
    ]],
        tmp
      )
    )
  end)

  it('handles % signs in modpath (#24491)', function()
    exec_lua [[
      vim.loader.enable()
    ]]

    local tmp = t.tmpname()
    assert(os.remove(tmp))
    assert(t.mkdir(tmp))
    assert(t.mkdir(tmp .. '/%'))
    local tmp1 = tmp .. '/%/x'
    local tmp2 = tmp .. '/%%x'

    t.write_file(tmp1, 'return 1', true)
    t.write_file(tmp2, 'return 2', true)
    vim.uv.fs_utime(tmp1, 0, 0)
    vim.uv.fs_utime(tmp2, 0, 0)
    eq(1, exec_lua('return loadfile(...)()', tmp1))
    eq(2, exec_lua('return loadfile(...)()', tmp2))
  end)
end)
