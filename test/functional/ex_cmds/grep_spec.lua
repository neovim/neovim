local helpers = require('test.functional.helpers')(after_each)
local clear, command, feed, ok, eval =
  helpers.clear, helpers.command, helpers.feed, helpers.ok, helpers.eval

describe(':grep', function()
  before_each(clear)

  it('does not hang on large input #2983', function()
    if eval("executable('grep')") == 0 then
      pending('missing "grep" command')
      return
    end

    command([[set grepprg=grep\ -r]])
    -- Change to test directory so that the test does not run too long.
    command('cd test')
    command('grep a **/*')
    feed('<cr>')  -- Press ENTER
    ok(eval('len(getqflist())') > 9000)  -- IT'S OVER 9000!!1
  end)

  it('works when both shellpipe and makeef are unset', function()
    if eval("executable('grep')") == 0 then
      pending('missing "grep" command')
      return
    end

    command([[set grepprg=grep\ -r]])
    command([[set shellpipe=]])
    command([[set makeef=]])
    -- Change to test directory so that the test does not run too long.
    command('cd test')
    command('grep a **/*')
    -- No need to press ENTER here (direct pipes are used).
    ok(eval('len(getqflist())') > 9000)  -- IT'S OVER 9000!!1
  end)
end)
