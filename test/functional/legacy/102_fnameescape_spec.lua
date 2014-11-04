-- Test if fnameescape is correct for special chars like!

local helpers = require('test.functional.helpers')
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local execute, expect = helpers.execute, helpers.expect

describe('fnameescape', function()
  setup(clear)

  it('is working', function()
    execute('let fname = "Xspa ce"')
    execute('try', 'exe "w! " . fnameescape(fname)', "put='Space'", 'endtry')
    execute('let fname = "Xemark!"')
    execute('try', 'exe "w! " . fnameescape(fname)', "put='ExclamationMark'", 'endtry')

    expect([[
      
      Space
      ExclamationMark]])
  end)

  teardown(function()
    os.remove("Xspa ce")
    os.remove("Xemark!")
  end)
end)
