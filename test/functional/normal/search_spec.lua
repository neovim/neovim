local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local command = helpers.command
local eq = helpers.eq
local eval = helpers.eval
local feed = helpers.feed
local pcall_err = helpers.pcall_err

describe('search (/)', function()
  before_each(clear)

  it('fails with huge column (%c) value #9930', function()
    eq([[Vim:E951: \% value too large]],
      pcall_err(command, "/\\v%18446744071562067968c"))
    eq([[Vim:E951: \% value too large]],
      pcall_err(command, "/\\v%2147483648c"))
  end)
end)

it('nv_next does not unnecessarily re-search (n/N)', function()
  clear()

  helpers.insert('foobar')
  feed('gg0/bar<cr>')
  eq('', eval('trim(execute(":messages"))'))
  feed('n')
  -- Check that normal_search was not called again by checking for a single
  -- message (would be 3 otherwise).
  eq('search hit BOTTOM, continuing at TOP', eval('trim(execute(":messages"))'))
end)
