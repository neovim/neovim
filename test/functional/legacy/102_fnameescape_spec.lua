-- Test if fnameescape is correct for special chars like!

local n = require('test.functional.testnvim')()
local t = require('test.testutil')

local describe, it, setup, teardown = t.describe, t.it, t.setup, t.teardown
local clear = n.clear
local command, expect = n.command, n.expect

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
