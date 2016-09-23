local helpers = require('test.functional.helpers')(after_each)

local eq = helpers.eq
local eval = helpers.eval
local meths = helpers.meths
local clear = helpers.clear

before_each(clear)

describe('extend()', function()
  it('suceeds to extend list with itself', function()
    meths.set_var('l', {1, {}})
    eq({1, {}, 1, {}}, eval('extend(l, l)'))
    eq({1, {}, 1, {}}, meths.get_var('l'))

    meths.set_var('l', {1, {}})
    eq({1, {}, 1, {}}, eval('extend(l, l, 0)'))
    eq({1, {}, 1, {}}, meths.get_var('l'))

    meths.set_var('l', {1, {}})
    eq({1, 1, {}, {}}, eval('extend(l, l, 1)'))
    eq({1, 1, {}, {}}, meths.get_var('l'))
  end)
end)
