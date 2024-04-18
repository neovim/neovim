-- Tests for writefile()

local t = require('test.functional.testutil')()
local clear, command, expect = t.clear, t.command, t.expect

describe('writefile', function()
  setup(clear)

  it('is working', function()
    command('%delete _')
    command('let f = tempname()')
    command('call writefile(["over","written"], f, "b")')
    command('call writefile(["hello","world"], f, "b")')
    command('call writefile(["!", "good"], f, "a")')
    command('call writefile(["morning"], f, "ab")')
    command('call writefile(["", "vimmers"], f, "ab")')
    command('bwipeout!')
    command('$put =readfile(f)')
    command('1 delete _')
    command('call delete(f)')

    -- Assert buffer contents.
    expect([[
      hello
      world!
      good
      morning
      vimmers]])
  end)
end)
