-- Tests for :set

local helpers = require('test.functional.helpers')(after_each)
local clear, execute, eval, eq =
  helpers.clear, helpers.execute, helpers.eval, helpers.eq

describe(':set', function()
  before_each(clear)

  it('handles backslash properly', function()
    execute('set iskeyword=a,b,c')
    execute('set iskeyword+=d')
    eq('a,b,c,d', eval('&iskeyword'))

    execute([[set iskeyword+=\\,e]])
    eq([[a,b,c,d,\,e]], eval('&iskeyword'))

    execute('set iskeyword-=e')
    eq([[a,b,c,d,\]], eval('&iskeyword'))

    execute([[set iskeyword-=\]])
    eq('a,b,c,d', eval('&iskeyword'))
  end)

  it('recognizes a trailing comma with +=', function()
    execute('set wildignore=*.png,')
    execute('set wildignore+=*.jpg')
    eq('*.png,*.jpg', eval('&wildignore'))
  end)
end)
