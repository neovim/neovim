-- Test for joining lines

local t = require('test.functional.testutil')()
local clear, eq = t.clear, t.eq
local eval, command = t.eval, t.command

describe('joining lines', function()
  before_each(clear)

  it('is working', function()
    command('new')
    command([[call setline(1, ['one', 'two', 'three', 'four'])]])
    command('normal J')
    eq('one two', eval('getline(1)'))
    command('%del')
    command([[call setline(1, ['one', 'two', 'three', 'four'])]])
    command('normal 10J')
    eq('one two three four', eval('getline(1)'))
  end)
end)
