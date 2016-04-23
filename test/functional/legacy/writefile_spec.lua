-- Tests for writefile()

local helpers = require('test.functional.helpers')
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect

describe('writefile', function()
  setup(clear)

  it('is working', function()
    execute('%delete _')
    execute('let f = tempname()')
    execute('call writefile(["over","written"], f, "b")')
    execute('call writefile(["hello","world"], f, "b")')
    execute('call writefile(["!", "good"], f, "a")')
    execute('call writefile(["morning"], f, "ab")')
    execute('call writefile(["", "vimmers"], f, "ab")')
    execute('bwipeout!')
    execute('$put =readfile(f)')
    execute('1 delete _')

    -- Assert buffer contents.
    expect([[
      hello
      world!
      good
      morning
      vimmers]])
  end)
end)
