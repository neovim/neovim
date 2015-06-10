-- Tests for :0argadd and :0argedit

local helpers = require('test.functional.helpers')
local eq, eval, clear, execute =
  helpers.eq, helpers.eval, helpers.clear, helpers.execute

describe('argument_0count', function()
  setup(clear)

  it('is working', function()
    execute('arga a b c d')
    eq({'a', 'b', 'c', 'd'}, eval('argv()'))
    execute('2argu')
    execute('0arga added')
    eq({'added', 'a', 'b', 'c', 'd'}, eval('argv()'))
    execute('2argu')
    execute('arga third')
    eq({'added', 'a', 'third', 'b', 'c', 'd'}, eval('argv()'))
    execute('%argd')
    execute('arga a b c d')
    execute('2argu')
    execute('0arge edited')
    eq({'edited', 'a', 'b', 'c', 'd'}, eval('argv()'))
    execute('2argu')
    execute('arga third')
    eq({'edited', 'a', 'third', 'b', 'c', 'd'}, eval('argv()'))
  end)
end)
