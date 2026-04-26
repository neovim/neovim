local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local eq = t.eq
local eval = n.eval
local clear = n.clear
local command = n.command
local source = n.source
local request = n.request

describe('autocmd', function()
  describe('OptionSet modified', function()
    before_each(clear)

    it('is triggered when modified and un-modified', function()
      source([[
      let g:modified = 0
      autocmd OptionSet modified let g:modified += 1
      ]])
      request('nvim_command', [[normal! aa\<Esc>]])
      eq(1, eval('g:modified'))
      request('nvim_command', [[normal! u]])
      eq(2, eval('g:modified'))
    end)

    it('triggers when writes non-current buffer #32817', function()
      source([[
      let g:modified = 0
      let g:second_trigger_buf = 0
      autocmd OptionSet modified let g:modified += 1 | if g:modified == 2 | let g:second_trigger_buf = bufnr() | endif
      ]])
      request('nvim_command', [[edit test_a | badd test_b]])
      request('nvim_command', [[normal! aa\<Esc>]])
      request('nvim_command', [[let g:buf_a = bufnr()]])
      request('nvim_command', [[bn]])
      request('nvim_command', [[wa]])
      os.remove('test_a')
      eq({ 2, true }, { eval('g:modified'), eval('g:buf_a') == eval('g:second_trigger_buf') })
    end)

    it('OptionSet triggers correctly when modified changes', function()
      command([[
        autocmd OptionSet modified call add(g:messages, string(!!v:option_old) . ' -> ' . string(!!v:option_new) . ' - actual: ' . &modified)
      ]])
      command('let g:messages = []')
      local fname = t.tmpname()
      command('new ' .. fname)
      command("call setline(1, 'hi')")
      command('write')
      command('set modified')
      eq({
        '0 -> 1 - actual: 1',
        '1 -> 0 - actual: 0',
        '0 -> 1 - actual: 1',
      }, eval('g:messages'))
      os.remove(fname)
    end)
  end)
end)
