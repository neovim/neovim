-- Test for joining lines

local helpers = require('test.functional.helpers')(after_each)
local clear, eq = helpers.clear, helpers.eq
local eval, command = helpers.eval, helpers.command

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
