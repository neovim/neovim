require('os')
local uv = vim.uv

local helpers = require('test.functional.helpers')(after_each)
local eval = helpers.eval
local command = helpers.command
local eq, neq = helpers.eq, helpers.neq
local tempfile = helpers.tmpname()
local source = helpers.source
local matches = helpers.matches
local read_file = helpers.read_file

-- tmpname() also creates the file on POSIX systems. Remove it again.
-- We just need the name, ignoring any race conditions.
if uv.fs_stat(tempfile).uid then
  os.remove(tempfile)
end

local function assert_file_exists(filepath)
  neq(nil, uv.fs_stat(filepath).uid)
end

local function assert_file_exists_not(filepath)
  eq(nil, uv.fs_stat(filepath))
end

describe(':profile', function()
  before_each(helpers.clear)

  after_each(function()
    helpers.expect_exit(command, 'qall!')
    if uv.fs_stat(tempfile).uid ~= nil then
      os.remove(tempfile)
    end
  end)

  describe('dump', function()
    it('works', function()
      eq(0, eval('v:profiling'))
      command('profile start ' .. tempfile)
      eq(1, eval('v:profiling'))
      assert_file_exists_not(tempfile)
      command('profile dump')
      assert_file_exists(tempfile)
    end)

    it('not resetting the profile', function()
      source([[
        function! Test()
        endfunction
      ]])
      command('profile start ' .. tempfile)
      assert_file_exists_not(tempfile)
      command('profile func Test')
      command('call Test()')
      command('profile dump')
      assert_file_exists(tempfile)
      local profile = read_file(tempfile)
      matches('Called 1 time', profile)
      command('call Test()')
      command('profile dump')
      assert_file_exists(tempfile)
      profile = read_file(tempfile)
      matches('Called 2 time', profile)
      command('profile stop')
    end)
  end)

  describe('stop', function()
    it('works', function()
      command('profile start ' .. tempfile)
      assert_file_exists_not(tempfile)
      command('profile stop')
      assert_file_exists(tempfile)
      eq(0, eval('v:profiling'))
    end)

    it('resetting the profile', function()
      source([[
        function! Test()
        endfunction
      ]])
      command('profile start ' .. tempfile)
      assert_file_exists_not(tempfile)
      command('profile func Test')
      command('call Test()')
      command('profile stop')
      assert_file_exists(tempfile)
      local profile = read_file(tempfile)
      matches('Called 1 time', profile)
      command('profile start ' .. tempfile)
      command('profile func Test')
      command('call Test()')
      command('profile stop')
      assert_file_exists(tempfile)
      profile = read_file(tempfile)
      matches('Called 1 time', profile)
    end)
  end)
end)
