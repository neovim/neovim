local helpers = require('test.functional.helpers')(after_each)
local clear, feed_command, feed, ok, eval =
  helpers.clear, helpers.feed_command, helpers.feed, helpers.ok, helpers.eval

describe(':grep', function()
  before_each(clear)

  it('does not hang on large input #2983', function()
    if eval("executable('grep')") == 0 then
      pending('missing "grep" command')
      return
    end

    feed_command([[set grepprg=grep\ -r]])
    -- Change to test directory so that the test does not run too long.
    feed_command('cd test')
    feed_command('grep a **/*')
    feed('<cr>')  -- Press ENTER
    ok(eval('len(getqflist())') > 9000)  -- IT'S OVER 9000!!1
  end)
end)
