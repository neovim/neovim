local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each, pending = t.describe, t.it, t.before_each, t.pending
local clear, ok, eval = n.clear, t.ok, n.eval

describe(':grep', function()
  before_each(clear)

  it('does not hang on large input #2983', function()
    if eval("executable('grep')") == 0 then
      pending('missing "grep" command')
      return
    end

    n.command('set grepprg=grep')
    n.feed(':grep N test/functional/fixtures/bigfile.txt<cr>')
    n.feed('<cr>') -- Press ENTER
    ok(eval('len(getqflist())') > 9000) -- IT'S OVER 9000!!1
  end)
end)
