local helpers = require('test.functional.helpers')(after_each)
local clear, eq, ok = helpers.clear,  helpers.eq, helpers.ok
local neq, command, funcs  = helpers.neq, helpers.command, helpers.funcs
local reltime, reltimestr, reltimefloat = funcs.reltime, funcs.reltimestr, funcs.reltimefloat

describe('reltimestr(), reltimefloat()', function()
  before_each(clear)

  it('Checks', function()
    local now = reltime()
    command('sleep 10m')
    local later = reltime()
    local elapsed = reltime(now)

    neq(reltimestr(elapsed), '0.0')
    ok(reltimefloat(elapsed) > 0.0)
    -- original vim test for < 0.1, but easily fails on travis
    ok(nil ~= string.match(reltimestr(elapsed), "0%."))
    ok(reltimefloat(elapsed) < 1.0)

    local same = reltime(now, now)
    local samestr = string.gsub(reltimestr(same), ' ', '')
    samestr = string.sub(samestr, 1, 5)

    eq('0.000', samestr)
    eq(0.0, reltimefloat(same))

    local differs = reltime(now, later)
    neq(reltimestr(differs), '0.0')
    ok(reltimefloat(differs) > 0.0)
    -- original vim test for < 0.1, but easily fails on travis
    ok(nil ~= string.match(reltimestr(differs), "0%."))
    ok(reltimefloat(differs) < 1.0)

  end)

  it('reltime() allows negative result #10452', function()
    local older_time = reltime()
    command('sleep 1m')
    local newer_time = reltime()

    -- Start/end swapped: should be something like -0.002123.
    local rv = tonumber(reltimestr(reltime(newer_time, older_time)))
    ok(rv < 0 and rv > -10)

    -- Not swapped: should be something like 0.002123.
    rv = tonumber(reltimestr(reltime(older_time, newer_time)))
    ok(rv > 0 and rv < 10)
  end)
end)
