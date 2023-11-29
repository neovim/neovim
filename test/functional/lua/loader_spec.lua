-- Test suite for testing interactions with API bindings
local helpers = require('test.functional.helpers')(after_each)

local exec_lua = helpers.exec_lua
local exec = helpers.exec
local command = helpers.command
local eq = helpers.eq

describe('vim.loader', function()
  before_each(helpers.clear)

  it('handles changing files (#23027)', function()
    exec_lua[[
      vim.loader.enable()
    ]]

    local tmp = helpers.tmpname()
    command('edit ' .. tmp)

    eq(1, exec_lua([[
      vim.api.nvim_buf_set_lines(0, 0, -1, true, {'_G.TEST=1'})
      vim.cmd.write()
      loadfile(...)()
      return _G.TEST
    ]], tmp))

    -- fs latency
    helpers.sleep(10)

    eq(2, exec_lua([[
      vim.api.nvim_buf_set_lines(0, 0, -1, true, {'_G.TEST=2'})
      vim.cmd.write()
      loadfile(...)()
      return _G.TEST
    ]], tmp))
  end)

  it('handles % signs in modpath (#24491)', function()
    exec_lua[[
      vim.loader.enable()
    ]]

    local tmp1, tmp2 = (function (t)
      assert(os.remove(t))
      assert(helpers.mkdir(t))
      assert(helpers.mkdir(t .. '/%'))
      return t .. '/%/x', t .. '/%%x'
    end)(helpers.tmpname())

    helpers.write_file(tmp1, 'return 1', true)
    helpers.write_file(tmp2, 'return 2', true)
    vim.uv.fs_utime(tmp1, 0, 0)
    vim.uv.fs_utime(tmp2, 0, 0)
    eq(1, exec_lua('return loadfile(...)()', tmp1))
    eq(2, exec_lua('return loadfile(...)()', tmp2))
  end)

  it('handles "." in modname for dynamic library correctly (#26308)', function()
    exec_lua [[
      vim.loader.enable()
    ]]

    local tmpdir = helpers.tmpname()
    -- make sure tmpdir is empty.
    assert(os.remove(tmpdir))

    -- mkdir_p does not work on windows => create separately.
    assert(helpers.mkdir(tmpdir))
    assert(helpers.mkdir(tmpdir .. '/lua'))

    -- Create file for mimicking lua-library.
    -- Content does not matter, append/write does not matter (file is empty at this point).
    helpers.write_file(tmpdir .. '/lua/foo.' .. (helpers.is_os('win') and 'dll' or 'so'), '', false)

    exec('set rtp+=' .. tmpdir)
    -- Call the function responsible for resolving the `require` of a dynamic library directly.
    -- The reason for skipping over `require` itself is that observing the correct behaviour
    -- (file is found and loadlib attempted) with it would require a valid library with the correct
    -- luaopen_foo_bar-symbol, which is more cumbersome than just placing an empty file at the
    -- correct location, which is all we need to see different behaviour with the loader-internal
    -- function.
    local ok, err_msg = pcall(exec_lua, [[ return package.loaders[3]('foo.bar') ]])

    -- Make sure the module is found.
    -- (loading the module fails at a later stage, but we can check for just that).
    eq(false, ok)

    -- make sure there is an error loading it, and not something else.
    if helpers.is_os('win') then
      eq(true, err_msg:match('not a valid Win32 application') ~= nil)
    elseif helpers.is_os('mac') then
      eq(true, err_msg:match('lua/foo.so, 0x0006') ~= nil)
    elseif helpers.is_os('freebsd') then
      eq(true, err_msg:match('foo.so: invalid file format') ~= nil)
    else
      eq(true, err_msg:match('foo.so: file too short') ~= nil)
    end

    -- Verify different behaviour for unavailable (as in not found) library.
    ok, err_msg = pcall(exec_lua, [[ return package.loaders[3]('foobar12345$') ]])
    eq(true, ok)
    eq('\ncache_loader_lib: module foobar12345$ not found', err_msg)
  end)
end)
