-- Cmdline-mode tests.

local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, insert, funcs, eq, feed =
  helpers.clear, helpers.insert, helpers.funcs, helpers.eq, helpers.feed
local eval = helpers.eval
local command = helpers.command
local meths = helpers.meths

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
      eq('line1abc\rline2somemoretext', funcs.getcmdline())

      -- Yank 2 lines charwise, then paste to cmdline.
      feed([[<C-\><C-N>gg05lyvj:<C-R>0]])
      -- <CR> inserted between lines, NOT after the final line.
      eq('abc\rline2', funcs.getcmdline())

      -- Yank 1 line linewise, then paste to cmdline.
      feed([[<C-\><C-N>ggyy:<C-R>0]])
      -- No <CR> inserted.
      eq('line1abc', funcs.getcmdline())
    end)

    it('pasting special register inserts <CR>, <NL>', function()
      feed([[:<C-R>="foo\nbar\rbaz"<CR>]])
      eq('foo\nbar\rbaz', funcs.getcmdline())
    end)
  end)

  it('Ctrl-Shift-V supports entering unsimplified key notations', function()
    feed(':"<C-S-V><C-J><C-S-V><C-@><C-S-V><C-[><C-S-V><C-S-M><C-S-V><M-C-I><C-S-V><C-D-J><CR>')

    eq('"<C-J><C-@><C-[><C-S-M><M-C-I><C-D-J>', eval('@:'))
  end)

  it('redraws statusline when toggling overstrike', function()
    local screen = Screen.new(60, 4)
    screen:set_default_attr_ids({
      [0] = {bold = true, foreground = Screen.colors.Blue},  -- NonText
      [1] = {reverse = true, bold = true},  -- StatusLine
    })
    screen:attach()
    command('set laststatus=2 statusline=%!mode(1)')
    feed(':')
    screen:expect{grid=[[
                                                                  |
      {0:~                                                           }|
      {1:c                                                           }|
      :^                                                           |
    ]]}
    feed('<Insert>')
    screen:expect{grid=[[
                                                                  |
      {0:~                                                           }|
      {1:cr                                                          }|
      :^                                                           |
    ]]}
  end)

  describe('history', function()
    it('correctly clears start of the history', function()
      -- Regression test: check absence of the memory leak when clearing start of
      -- the history using ex_getln.c/clr_history().
      eq(1, funcs.histadd(':', 'foo'))
      eq(1, funcs.histdel(':'))
      eq('', funcs.histget(':', -1))
    end)

    it('correctly clears end of the history', function()
      -- Regression test: check absence of the memory leak when clearing end of
      -- the history using ex_getln.c/clr_history().
      meths.set_option_value('history', 1, {})
      eq(1, funcs.histadd(':', 'foo'))
      eq(1, funcs.histdel(':'))
      eq('', funcs.histget(':', -1))
    end)

    it('correctly removes item from history', function()
      -- Regression test: check that ex_getln.c/del_history_idx() correctly clears
      -- history index after removing history entry. If it does not then deleting
      -- history will result in a double free.
      eq(1, funcs.histadd(':', 'foo'))
      eq(1, funcs.histadd(':', 'bar'))
      eq(1, funcs.histadd(':', 'baz'))
      eq(1, funcs.histdel(':', -2))
      eq(1, funcs.histdel(':'))
      eq('', funcs.histget(':', -1))
    end)
  end)
end)
