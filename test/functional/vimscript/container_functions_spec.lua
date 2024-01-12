local helpers = require('test.functional.helpers')(after_each)

local eq = helpers.eq
local eval = helpers.eval
local api = helpers.api
local clear = helpers.clear

before_each(clear)

describe('extend()', function()
  it('succeeds to extend list with itself', function()
    api.nvim_set_var('l', { 1, {} })
    eq({ 1, {}, 1, {} }, eval('extend(l, l)'))
    eq({ 1, {}, 1, {} }, api.nvim_get_var('l'))

    api.nvim_set_var('l', { 1, {} })
    eq({ 1, {}, 1, {} }, eval('extend(l, l, 0)'))
    eq({ 1, {}, 1, {} }, api.nvim_get_var('l'))

    api.nvim_set_var('l', { 1, {} })
    eq({ 1, 1, {}, {} }, eval('extend(l, l, 1)'))
    eq({ 1, 1, {}, {} }, api.nvim_get_var('l'))
  end)
end)
