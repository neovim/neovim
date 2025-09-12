local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local command = n.command
local call = n.call
local feed = n.feed
local eval = n.eval
local eq = t.eq

describe('CompleteDone', function()
  before_each(clear)

  describe('sets v:event.reason', function()
    before_each(function()
      clear()
      command('autocmd CompleteDone * let g:donereason = v:event.reason')
      feed('i')
      call('complete', call('col', '.'), { 'foo', 'bar' })
    end)

    it('accept', function()
      feed('<C-y>')
      eq('accept', eval('g:donereason'))
    end)

    it('cancel', function()
      feed('<C-e>')
      eq('cancel', eval('g:donereason'))
    end)

    describe('discard', function()
      it('on non-keyword character', function()
        feed('<Space>')
        eq('discard', eval('g:donereason'))
      end)

      it('on mode change', function()
        feed('<Esc>')
        eq('discard', eval('g:donereason'))
      end)

      it('when overridden by another complete()', function()
        call('complete', call('col', '.'), { 'bar', 'baz' })
        eq('discard', eval('g:donereason'))
      end)
    end)
  end)
end)
