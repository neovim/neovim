local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it = t.describe, t.it
local clear = n.clear

local exec_lua = n.exec_lua
local eq = t.eq

describe('vim._core.time', function()
  it('fmt_rtime(), fmt_ago()', function()
    clear()
    local function fmt_rtime(seconds)
      return exec_lua(function()
        return require('vim._core.time').fmt_rtime(seconds)
      end)
    end

    -- Singular/plural works
    eq('1 second', fmt_rtime(1))
    eq('2 seconds', fmt_rtime(2))
    eq('1 minute', fmt_rtime(62))
    eq('2 minutes', fmt_rtime(121))

    -- Exact units
    eq('0 seconds', fmt_rtime(0))
    eq('1 minute', fmt_rtime(60))
    eq('1 hour', fmt_rtime(3600))
    eq('1 day', fmt_rtime(86400))

    -- Some random times: the largest unit only
    eq('1 hour', fmt_rtime(3978))
    eq('7 hours', fmt_rtime(25681))
    eq('3 days', fmt_rtime(259277))

    -- A second before a day
    eq('23 hours', fmt_rtime(86399))

    -- One year
    eq('365 days', fmt_rtime(31536000))

    local function fmt_ago(seconds)
      return exec_lua(function()
        return require('vim._core.time').fmt_ago((os.time() - seconds) * 1e9)
      end)
    end

    eq('just now', fmt_ago(30))
    eq('1 minute ago', fmt_ago(90))
    eq('2 hours ago', fmt_ago(7300))
    eq('3 days ago', fmt_ago(259277))
    -- In the future (e.g. clock skew).
    eq('just now', fmt_ago(-100))
  end)
end)
