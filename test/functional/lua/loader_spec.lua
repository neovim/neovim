-- Test suite for testing interactions with API bindings
local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each = t.describe, t.it, t.before_each
local exec_lua = n.exec_lua
local command = n.command
local clear = n.clear
local eq = t.eq

describe('vim.loader', function()
  before_each(clear)

  it('can be disabled', function()
    exec_lua(function()
      local orig_loader = _G.loadfile
      local orig_loaders = { unpack(package.loaders) }
      vim.loader.enable()
      assert(orig_loader ~= _G.loadfile)
      vim.loader.enable(false)
      assert(orig_loader == _G.loadfile)
      assert(vim.deep_equal(orig_loaders, package.loaders))
    end)
  end)

  it('works with --luamod-dev #27413', function()
    clear({ args = { '--luamod-dev' } })
    exec_lua(function()
      vim.loader.enable()

      require('vim.fs')

      -- try to load other vim submodules as well (Nvim Lua stdlib)
      for key, _ in pairs(vim._submodules) do
        local modname = 'vim.' .. key -- e.g. "vim.fs"

        local lhs = vim[key]
        local rhs = require(modname)
        assert(
          lhs == rhs,
          ('%s != require("%s"), %s != %s'):format(modname, modname, tostring(lhs), tostring(rhs))
        )
      end
    end)
  end)

  it('handles changing files #23027', function()
    exec_lua(function()
      vim.loader.enable()
    end)

    local tmp = t.tmpname()
    command('edit ' .. tmp)

    eq(
      1,
      exec_lua(function()
        vim.api.nvim_buf_set_lines(0, 0, -1, true, { '_G.TEST=1' })
        vim.cmd.write()
        loadfile(tmp)()
        return _G.TEST
      end)
    )

    -- fs latency
    vim.uv.sleep(10)

    eq(
      2,
      exec_lua(function()
        vim.api.nvim_buf_set_lines(0, 0, -1, true, { '_G.TEST=2' })
        vim.cmd.write()
        loadfile(tmp)()
        return _G.TEST
      end)
    )
  end)

  it('handles % signs in modpath #24491', function()
    exec_lua [[
      vim.loader.enable()
    ]]

    local tmp = t.tmpname(false)
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

  it('caches deeply nested module paths #29372 #25008', function()
    local root = t.tmpname(false)
    local rtp = root .. ('/' .. ('x'):rep(80)):rep(3)
    n.fn.mkdir(rtp .. '/lua', 'p')
    t.write_file(rtp .. '/lua/long_path.lua', 'return 42')
    eq(
      { 42, 42, 1 },
      exec_lua(function(path, cache)
        vim.loader.path = cache
        vim.loader.enable()
        vim.opt.runtimepath:prepend(path)
        local fs_open = vim.uv.fs_open
        local writes = 0
        vim.uv.fs_open = function(name, mode, ...)
          if mode == 'w' and vim.startswith(name, cache .. '/') then
            writes = writes + 1
          end
          return fs_open(name, mode, ...)
        end
        local first = require('long_path')
        package.loaded.long_path = nil
        local second = require('long_path')
        vim.uv.fs_open = fs_open
        return { first, second, writes }
      end, rtp, root .. '/cache')
    )
    for name in vim.fs.dir(root .. '/cache') do
      -- eCryptfs has a smaller component limit than most filesystems.
      t.ok(#name <= 143, 'at most 143 bytes', #name)
    end
  end)

  it('loads cached files in fast events', function()
    local tmp = t.tmpname()
    t.write_file(tmp, 'return 42')
    eq(
      { true, 42, 42 },
      exec_lua(function(path)
        vim.loader.enable()
        local timer = vim.uv.new_timer()
        local result
        timer:start(0, 0, function()
          result = {
            pcall(function()
              return assert(loadfile(path))(), assert(loadfile(path))()
            end),
          }
          timer:close()
        end)
        assert(vim.wait(1000, function()
          return result ~= nil
        end))
        return result
      end, tmp)
    )
  end)

  it('indents error message #29809', function()
    local errmsg = exec_lua [[
      vim.loader.enable()
      local _, errmsg = pcall(require, 'non_existent_module')
      return errmsg
    ]]
    local errors = vim.split(errmsg, '\n')
    eq("\tcache_loader: module 'non_existent_module' not found", errors[3])
    eq("\tcache_loader_lib: module 'non_existent_module' not found", errors[4])
  end)
end)
