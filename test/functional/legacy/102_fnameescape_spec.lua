-- Test if fnameescape is correct for special chars like!

local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local command, expect = helpers.command, helpers.expect

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
    os.remove("Xspa ce")
    os.remove("Xemark!")
  end)
end)
