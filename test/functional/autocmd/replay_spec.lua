local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local eval = helpers.eval
local source_vim = helpers.source
local feed = helpers.feed

describe('ReplayEnter', function()
  before_each(clear)
  it('works', function()
    source_vim([[
      autocmd ReplayEnter * let g:info = { 'register': reg_executing(), 'line': getline(1) }
    ]])
    feed('iab<Esc>')
    feed('qqyiwPq')
    feed('@q')

    eq({ register = 'q', line = 'abab' }, eval('g:info'))
    eq('abababab', eval('getline(1)'))
  end)
end)

describe('ReplayLeave', function()
  before_each(clear)
  it('works', function()
    source_vim([[
      autocmd ReplayLeave * let g:info = { 'register': reg_executing(), 'line': getline(1) }
    ]])
    feed('iab<Esc>')
    feed('qqyiwPq')
    feed('@q')

    eq({ register = 'q', line = 'abababab' }, eval('g:info'))
    eq('abababab', eval('getline(1)'))
  end)
end)
