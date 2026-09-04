local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local describe, it, before_each, after_each = t.describe, t.it, t.before_each, t.after_each
local uv = vim.uv
require('os')

local eval = n.eval
local command = n.command
local eq, neq = t.eq, t.neq
local finally = t.finally
local fn = n.fn
local nvim_prog = n.nvim_prog
local tempfile = t.tmpname(false)
local source = n.source
local matches = t.matches
local read_file = t.read_file
local write_file = t.write_file

local function assert_file_exists(filepath)
  neq(nil, uv.fs_stat(filepath).uid)
end

local function assert_file_exists_not(filepath)
  eq(nil, uv.fs_stat(filepath))
end

describe(':profile', function()
  before_each(n.clear)

  after_each(function()
    n.expect_exit(command, 'qall!')
    if uv.fs_stat(tempfile) ~= nil then
      -- Delete the tempfile. We just need the name, ignoring any race conditions.
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

  describe('eager dump', function()
    local function start_busy_profile(profile_options)
      local script = t.tmpname(false)
      write_file(
        script,
        ([=[
          %s

          function! Busy()
            let g:profile_test = 0
            while 1
              let g:profile_test += 1
            endwhile
          endfunction

          profile start %s
          profile func Busy
          call Busy()
        ]=]):format(profile_options or '', tempfile)
      )

      local job = fn.jobstart(
        { nvim_prog, '-u', 'NONE', '-i', 'NONE', '--headless', '-S', script },
        { clear_env = true, env = { PATH = fn.getenv('PATH') } }
      )
      finally(function()
        pcall(fn.jobstop, job)
        pcall(fn.jobwait, { job }, 5000)
        os.remove(script)
      end)
      return job
    end

    it('writes the profile while profiling is still running', function()
      eq(1000, eval('&profiledumpinterval'))
      local job = start_busy_profile()

      uv.sleep(1100)
      eq(-1, fn.jobwait({ job }, 0)[1])
      assert_file_exists(tempfile)
      matches('FUNCTION  Busy()', read_file(tempfile))
    end)

    it("can be disabled with 'profiledumpinterval'", function()
      local job = start_busy_profile('set profiledumpinterval=0')

      uv.sleep(100)
      eq(-1, fn.jobwait({ job }, 0)[1])
      assert_file_exists_not(tempfile)
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
