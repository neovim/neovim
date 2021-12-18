-- Cmdline-mode tests.

local helpers = require('test.functional.helpers')(after_each)
local clear, insert, funcs, eq, feed =
  helpers.clear, helpers.insert, helpers.funcs, helpers.eq, helpers.feed
local meths = helpers.meths

describe('cmdline CTRL-R', function()
  before_each(clear)

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

describe('cmdline history', function()
  before_each(clear)

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
    meths.set_option('history', 1)
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
