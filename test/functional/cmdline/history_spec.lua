local helpers = require('test.functional.helpers')(after_each)
local clear, meths, funcs, eq =
  helpers.clear, helpers.meths, helpers.funcs, helpers.eq

describe('history support code', function()
  before_each(clear)

  it('correctly clears start of the history', function()
    -- Regression test: check absense of the memory leak when clearing start of
    -- the history using ex_getln.c/clr_history().
    eq(1, funcs.histadd(':', 'foo'))
    eq(1, funcs.histdel(':'))
    eq('', funcs.histget(':', -1))
  end)

  it('correctly clears end of the history', function()
    -- Regression test: check absense of the memory leak when clearing end of
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
