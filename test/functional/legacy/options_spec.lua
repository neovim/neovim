-- Test for ":options".

local helpers = require('test.functional.helpers')
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local execute, expect = helpers.execute, helpers.expect

describe('options', function()
  setup(clear)

  it('is working', function()
    insert('result')

    execute("let caught = 'ok'")
    execute('try', 'options', 'catch', 'let caught = v:throwpoint . "\n" . v:exception', 'endtry')
    execute('buf 1')
    execute('$put =caught')

    expect("result\nok")
  end)
end)
