-- Test for joining lines

local helpers = require('test.functional.helpers')(after_each)
local clear, eq = helpers.clear, helpers.eq
local eval, execute = helpers.eval, helpers.execute

describe('joining lines', function()
  before_each(clear)

  it('is working', function()
    execute('new')
    execute([[call setline(1, ['one', 'two', 'three', 'four'])]])
    execute('normal J')
    eq('one two', eval('getline(1)'))
    execute('%del')
    execute([[call setline(1, ['one', 'two', 'three', 'four'])]])
    execute('normal 10J')
    eq('one two three four', eval('getline(1)'))
  end)
end)
