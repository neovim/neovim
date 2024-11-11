-- Cmdline-mode tests.

local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear, insert, fn, eq, feed = n.clear, n.insert, n.fn, t.eq, n.feed
local eval = n.eval
local command = n.command
local api = n.api

describe('cmdline', function()
  before_each(clear)

  describe('Ctrl-R', function()
    it('pasting non-special register inserts <CR> *between* lines', function()
      insert([[
      line1abc
      line2somemoretext
      ]])
      -- Yank 2 lines linewise, then paste to cmdline.
      feed([[<C-\><C-N>gg0yj:<C-R>0]])
      -- <CR> inserted between lines, NOT after the final line.
      eq('line1abc\rline2somemoretext', fn.getcmdline())

      -- Yank 2 lines charwise, then paste to cmdline.
      feed([[<C-\><C-N>gg05lyvj:<C-R>0]])
      -- <CR> inserted between lines, NOT after the final line.
      eq('abc\rline2', fn.getcmdline())

      -- Yank 1 line linewise, then paste to cmdline.
      feed([[<C-\><C-N>ggyy:<C-R>0]])
      -- No <CR> inserted.
      eq('line1abc', fn.getcmdline())
    end)

    it('pasting special register inserts <CR>, <NL>', function()
      feed([[:<C-R>="foo\nbar\rbaz"<CR>]])
      eq('foo\nbar\rbaz', fn.getcmdline())
    end)

    it('pasting handles composing chars properly', function()
      local screen = Screen.new(60, 4)
      -- 'arabicshape' cheats and always redraws everything which trivially works,
      -- this test is for partial redraws in 'noarabicshape' mode.
      command('set noarabicshape')
      fn.setreg('a', '💻')
      feed(':test 🧑‍')
      screen:expect([[
                                                                    |
        {1:~                                                           }|*2
        :test 🧑‍^                                                    |
      ]])
      feed('<c-r><c-r>a')
      screen:expect([[
                                                                    |
        {1:~                                                           }|*2
        :test 🧑‍💻^                                                    |
      ]])
    end)
  end)

  it('Ctrl-Shift-V supports entering unsimplified key notations', function()
    feed(':"<C-S-V><C-J><C-S-V><C-@><C-S-V><C-[><C-S-V><C-S-M><C-S-V><M-C-I><C-S-V><C-D-J><CR>')

    eq('"<C-J><C-@><C-[><C-S-M><M-C-I><C-D-J>', eval('@:'))
  end)

  it('redraws statusline when toggling overstrike', function()
    local screen = Screen.new(60, 4)
    command('set laststatus=2 statusline=%!mode(1)')
    feed(':')
    screen:expect {
      grid = [[
                                                                  |
      {1:~                                                           }|
      {3:c                                                           }|
      :^                                                           |
    ]],
    }
    feed('<Insert>')
    screen:expect {
      grid = [[
                                                                  |
      {1:~                                                           }|
      {3:cr                                                          }|
      :^                                                           |
    ]],
    }
  end)

  describe('history', function()
    it('correctly clears start of the history', function()
      -- Regression test: check absence of the memory leak when clearing start of
      -- the history using cmdhist.c/clr_history().
      eq(1, fn.histadd(':', 'foo'))
      eq(1, fn.histdel(':'))
      eq('', fn.histget(':', -1))
    end)

    it('correctly clears end of the history', function()
      -- Regression test: check absence of the memory leak when clearing end of
      -- the history using cmdhist.c/clr_history().
      api.nvim_set_option_value('history', 1, {})
      eq(1, fn.histadd(':', 'foo'))
      eq(1, fn.histdel(':'))
      eq('', fn.histget(':', -1))
    end)

    it('correctly removes item from history', function()
      -- Regression test: check that cmdhist.c/del_history_idx() correctly clears
      -- history index after removing history entry. If it does not then deleting
      -- history will result in a double free.
      eq(1, fn.histadd(':', 'foo'))
      eq(1, fn.histadd(':', 'bar'))
      eq(1, fn.histadd(':', 'baz'))
      eq(1, fn.histdel(':', -2))
      eq(1, fn.histdel(':'))
      eq('', fn.histget(':', -1))
    end)
  end)
end)
