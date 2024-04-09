-- Test if fnameescape is correct for special chars like!

local t = require('test.functional.testutil')()
local clear = t.clear
local command, expect = t.command, t.expect

describe('fnameescape', function()
  setup(clear)

  it('is working', function()
    command('let fname = "Xspa ce"')
    command('try | exe "w! " . fnameescape(fname) | put=\'Space\' | endtry')
    command('let fname = "Xemark!"')
    command('try | exe "w! " . fnameescape(fname) | put=\'ExclamationMark\' | endtry')

    expect([[

      Space
      ExclamationMark]])
  end)

  teardown(function()
    os.remove('Xspa ce')
    os.remove('Xemark!')
  end)
end)
