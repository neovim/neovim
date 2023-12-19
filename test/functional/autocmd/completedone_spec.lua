local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local command = helpers.command
local call = helpers.call
local feed = helpers.feed
local eval = helpers.eval
local eq = helpers.eq

describe('CompleteDone', function()
  before_each(clear)

  describe('sets correct reason in v:event', function()
    before_each(function()
      clear()
      command('autocmd CompleteDone * let g:donereason = v:event.reason')
      feed('i')
      call('complete', call('col', '.'), {'foo', 'bar'})
    end)

    it('accepted', function()
      feed('<C-y>')
      eq('accepted', eval('g:donereason'))
    end)
    it('canceled', function()
      feed('<C-e>')
      eq('canceled', eval('g:donereason'))
    end)
    it('nonkw', function()
      feed('<Esc>')
      eq('nonkw', eval('g:donereason'))
    end)
    it('overridden', function()
      feed('a')
      eq('overridden', eval('g:donereason'))
    end)
  end)
end)
