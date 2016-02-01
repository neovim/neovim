-- Tests for :set

local helpers = require('test.functional.helpers')
local clear, execute, eval, eq =
  helpers.clear, helpers.execute, helpers.eval, helpers.eq

describe(':set', function()
  before_each(clear)

  it('recognizes a trailing comma with +=', function()
    execute('set wildignore=*.png,')
    execute('set wildignore+=*.jpg')
    eq('*.png,*.jpg', eval('&wildignore'))
  end)
end)
