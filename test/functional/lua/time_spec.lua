local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear

local exec_lua = n.exec_lua
local eq = t.eq

describe('vim._core.time', function()
  it('pretty_rtime()', function()
    clear()
    local function fmt_rtime(seconds)
      return exec_lua(function()
        return require('vim._core.time').fmt_rtime(seconds)
      end)
    end

    -- Singular/plural works
    eq('1 second', fmt_rtime(1))
    eq('2 seconds', fmt_rtime(2))
    eq('1 minute, 2 seconds', fmt_rtime(62))
    eq('2 minutes, 1 second', fmt_rtime(121))

    -- 0 units are included only when trailing
    -- Seconds are included while leading, as they are by themselves
    eq('0 seconds', fmt_rtime(0))
    eq('1 minute, 0 seconds', fmt_rtime(60))
    eq('1 hour, 0 minutes, 0 seconds', fmt_rtime(3600))
    eq('1 day, 0 hours, 0 minutes, 0 seconds', fmt_rtime(86400))

    -- Some random times
    eq('1 hour, 6 minutes, 18 seconds', fmt_rtime(3978))
    eq('7 hours, 8 minutes, 1 second', fmt_rtime(25681))
    eq('3 days, 0 hours, 1 minute, 17 seconds', fmt_rtime(259277))

    -- A second before a day
    eq('23 hours, 59 minutes, 59 seconds', fmt_rtime(86399))

    -- One year
    eq('365 days, 0 hours, 0 minutes, 0 seconds', fmt_rtime(31536000))
  end)
end)
