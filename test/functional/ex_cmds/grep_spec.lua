local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear, ok, eval = n.clear, t.ok, n.eval

describe(':grep', function()
  before_each(clear)

  it('does not hang on large input #2983', function()
    if eval("executable('grep')") == 0 then
      pending('missing "grep" command')
      return
    end

    n.command([[set grepprg=grep\ -r]])
    -- Change to test directory so that the test does not run too long.
    n.command('cd test')
    n.feed(':grep a **/*<cr>')
    n.feed('<cr>') -- Press ENTER
    ok(eval('len(getqflist())') > 9000) -- IT'S OVER 9000!!1
  end)
end)
