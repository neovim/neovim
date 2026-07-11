local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local eq = t.eq
local eval = n.eval
local source_vim = n.source
local feed = n.feed

describe('MacroEnter', function()
  before_each(clear)
  it('works', function()
    source_vim([[
      autocmd MacroEnter * let g:info = { 'register': reg_executing(), 'line': getline(1) }
    ]])
    feed('iab<Esc>')
    feed('qqyiwPq')
    feed('@q')

    eq({ register = 'q', line = 'abab' }, eval('g:info'))
    eq('abababab', eval('getline(1)'))
  end)
end)

describe('MacroLeave', function()
  before_each(clear)
  it('works', function()
    source_vim([[
      autocmd MacroLeave * let g:info = { 'register': reg_executing(), 'line': getline(1) }
    ]])
    feed('iab<Esc>')
    feed('qqyiwPq')
    feed('@q')

    eq({ register = 'q', line = 'abababab' }, eval('g:info'))
    eq('abababab', eval('getline(1)'))
  end)
end)
