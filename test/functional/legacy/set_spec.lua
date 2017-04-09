-- Tests for :set

local helpers = require('test.functional.helpers')(after_each)
local clear, command, eval, eq =
  helpers.clear, helpers.command, helpers.eval, helpers.eq

describe(':set', function()
  before_each(clear)

  it('handles backslash properly', function()
    command('set iskeyword=a,b,c')
    command('set iskeyword+=d')
    eq('a,b,c,d', eval('&iskeyword'))

    command([[set iskeyword+=\\,e]])
    eq([[a,b,c,d,\,e]], eval('&iskeyword'))

    command('set iskeyword-=e')
    eq([[a,b,c,d,\]], eval('&iskeyword'))

    command([[set iskeyword-=\]])
    eq('a,b,c,d', eval('&iskeyword'))
  end)

  it('recognizes a trailing comma with +=', function()
    command('set wildignore=*.png,')
    command('set wildignore+=*.jpg')
    eq('*.png,*.jpg', eval('&wildignore'))
  end)
end)
