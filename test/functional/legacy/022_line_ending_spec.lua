-- Tests for file with some lines ending in CTRL-M, some not

local helpers = require('test.functional.helpers')
local clear, feed = helpers.clear, helpers.feed
local execute, expect = helpers.execute, helpers.expect

describe('line ending', function()
  setup(clear)

  it('is working', function()
    feed('i', [[
      this lines ends in a<C-V><C-M>
      this one doesn't
      this one does<C-V><C-M>
      and the last one doesn't]], '<ESC>')

    execute('set ta tx')
    execute('e!')

    expect("this lines ends in a\r\n"..
           "this one doesn't\n"..
           "this one does\r\n"..
           "and the last one doesn't")
  end)
end)
