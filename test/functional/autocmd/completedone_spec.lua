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
      command('set completeopt+=noinsert')
      command('autocmd CompleteDone * let g:donereason = v:event.reason')
      feed('i')
      call('complete', call('col', '.'), { 'foo', 'bar' })
    end)

    it('accept', function()
      feed('<C-y>')
      eq('accept', eval('g:donereason'))
    end)

    it('accept when candidate is inserted without noinsert #38160', function()
      command('set completeopt=menu,menuone')
      feed('<ESC>Stest<CR><C-N><ESC>')
      eq('accept', eval('g:donereason'))
      eq('test', n.api.nvim_get_current_line())
      feed('Stip<CR>t<C-N><C-N><ESC>')
      eq('accept', eval('g:donereason'))
      eq('tip', n.api.nvim_get_current_line())
      feed('Stry<CR>t<C-N><C-N><C-N><Space>')
      eq('accept', eval('g:donereason'))
      eq('try ', n.api.nvim_get_current_line())
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
