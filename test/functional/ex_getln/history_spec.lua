local helpers = require('test.functional.helpers')
local clear, nvim, call, eq =
  helpers.clear, helpers.nvim, helpers.call, helpers.eq

describe('history support code', function()
  before_each(clear)

  local histadd = function(...) return call('histadd', ...) end
  local histget = function(...) return call('histget', ...) end
  local histdel = function(...) return call('histdel', ...) end

  it('correctly clears start of the history', function()
    -- Regression test: check absense of the memory leak when clearing start of 
    -- the history using ex_getln.c/clr_history().
    eq(1, histadd(':', 'foo'))
    eq(1, histdel(':'))
    eq('', histget(':', -1))
  end)

  it('correctly clears end of the history', function()
    -- Regression test: check absense of the memory leak when clearing end of 
    -- the history using ex_getln.c/clr_history().
    nvim('set_option', 'history', 1)
    eq(1, histadd(':', 'foo'))
    eq(1, histdel(':'))
    eq('', histget(':', -1))
  end)

  it('correctly removes item from history', function()
    -- Regression test: check that ex_getln.c/del_history_idx() correctly clears 
    -- history index after removing history entry. If it does not then deleting 
    -- history will result in a double free.
    eq(1, histadd(':', 'foo'))
    eq(1, histadd(':', 'bar'))
    eq(1, histadd(':', 'baz'))
    eq(1, histdel(':', -2))
    eq(1, histdel(':'))
    eq('', histget(':', -1))
  end)
end)
