local helpers = require('test.functional.helpers')(after_each)
local clear, execute, feed, ok, eval =
  helpers.clear, helpers.execute, helpers.feed, helpers.ok, helpers.eval

describe(':grep', function()
  before_each(clear)

  it('does not hang on large input #2983', function()
    if eval("executable('grep')") == 0 then
      pending('missing "grep" command')
      return
    end

    execute([[set grepprg=grep\ -r]])
    -- Change to test directory so that the test does not run too long.
    execute('cd test')
    execute('grep a **/*')
    feed('<cr>')  -- Press ENTER
    ok(eval('len(getqflist())') > 9000)  -- IT'S OVER 9000!!1
  end)
end)
