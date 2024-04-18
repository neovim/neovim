local t = require('test.functional.testutil')()
local eq = t.eq
local eval = t.eval
local clear = t.clear

describe('Division operator', function()
  before_each(clear)

  it('returns infinity on {positive}/0.0', function()
    eq("str2float('inf')", eval('string(1.0/0.0)'))
    eq("str2float('inf')", eval('string(1.0e-100/0.0)'))
    eq("str2float('inf')", eval('string(1.0e+100/0.0)'))
    eq("str2float('inf')", eval('string((1.0/0.0)/0.0)'))
  end)

  it('returns -infinity on {negative}/0.0', function()
    eq("-str2float('inf')", eval('string((-1.0)/0.0)'))
    eq("-str2float('inf')", eval('string((-1.0e-100)/0.0)'))
    eq("-str2float('inf')", eval('string((-1.0e+100)/0.0)'))
    eq("-str2float('inf')", eval('string((-1.0/0.0)/0.0)'))
  end)

  it('returns NaN on 0.0/0.0', function()
    eq("str2float('nan')", eval('string(0.0/0.0)'))
    eq("str2float('nan')", eval('string(-(0.0/0.0))'))
    eq("str2float('nan')", eval('string((-0.0)/0.0)'))
  end)
end)
