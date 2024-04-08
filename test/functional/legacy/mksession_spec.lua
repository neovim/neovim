local t = require('test.functional.testutil')(after_each)
local clear = t.clear
local command = t.command
local fn = t.fn
local eq = t.eq

describe('mksession', function()
  before_each(clear)

  after_each(function()
    os.remove('Xtest_mks.out')
  end)

  it('supports "skiprtp" value', function()
    command('set sessionoptions+=options')
    command('set rtp+=$HOME')
    command('set pp+=$HOME')
    command('mksession! Xtest_mks.out')
    local found_rtp = 0
    local found_pp = 0
    for _, line in pairs(fn.readfile('Xtest_mks.out', 'b')) do
      if line:find('set runtimepath') then
        found_rtp = found_rtp + 1
      end
      if line:find('set packpath') then
        found_pp = found_pp + 1
      end
    end
    eq(1, found_rtp)
    eq(1, found_pp)

    command('set sessionoptions+=skiprtp')
    command('mksession! Xtest_mks.out')
    local found_rtp_or_pp = 0
    for _, line in pairs(fn.readfile('Xtest_mks.out', 'b')) do
      if line:find('set runtimepath') or line:find('set packpath') then
        found_rtp_or_pp = found_rtp_or_pp + 1
      end
    end
    eq(0, found_rtp_or_pp)
  end)
end)
