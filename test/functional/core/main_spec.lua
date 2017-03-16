local lfs = require('lfs')
local helpers = require('test.functional.helpers')(after_each)
local global_helpers = require('test.helpers')

local eq = helpers.eq
local neq = helpers.neq
local sleep = helpers.sleep
local nvim_prog = helpers.nvim_prog
local write_file = helpers.write_file

local popen_w = global_helpers.popen_w
local popen_r = global_helpers.popen_r

describe('Command-line option', function()
  describe('-s', function()
    local fname = 'Xtest-functional-core-main-s'
    local dollar_fname = '$' .. fname
    before_each(function()
      os.remove(fname)
      os.remove(dollar_fname)
    end)
    after_each(function()
      os.remove(fname)
      os.remove(dollar_fname)
    end)
    it('treats - as stdin', function()
      eq(nil, lfs.attributes(fname))
      local pipe = popen_w(
        nvim_prog, '-u', 'NONE', '-i', 'NONE', '--headless', '-s', '-',
        fname)
      pipe:write(':call setline(1, "42")\n')
      pipe:write(':wqall!\n')
      pipe:close()
      local max_sec = 10
      while max_sec > 0 do
        local attrs = lfs.attributes(fname)
        if attrs then
          eq(#('42\n'), attrs.size)
          break
        else
          max_sec = max_sec - 1
          sleep(1000)
        end
      end
      neq(0, max_sec)
    end)
    it('does not expand $VAR', function()
      eq(nil, lfs.attributes(fname))
      eq(true, not not dollar_fname:find('%$%w+'))
      write_file(dollar_fname, ':call setline(1, "100500")\n:wqall!\n')
      local pipe = popen_r(
        nvim_prog, '-u', 'NONE', '-i', 'NONE', '--headless', '-s', dollar_fname,
        fname)
        local stdout = pipe:read('*a')
        eq('', stdout)
        local attrs = lfs.attributes(fname)
        eq(#('100500\n'), attrs.size)
    end)
  end)
end)
