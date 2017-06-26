local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local eq = helpers.eq
local eval = helpers.eval
local command = helpers.command
local source = helpers.source

describe('lispwords', function()
  before_each(clear)

  it('should be set global-local',function()
    source([[
      setglobal lispwords=foo,bar,baz
      setlocal lispwords-=foo
      setlocal lispwords+=quux]])
    eq('foo,bar,baz', eval('&g:lispwords'))
    eq('bar,baz,quux', eval('&l:lispwords'))
    eq('bar,baz,quux', eval('&lispwords'))

    command('setlocal lispwords<')
    eq('foo,bar,baz', eval('&g:lispwords'))
    eq('foo,bar,baz', eval('&l:lispwords'))
    eq('foo,bar,baz', eval('&lispwords'))
  end)
end)
