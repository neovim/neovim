-- Tests for writefile()

local helpers = require('test.functional.helpers')
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect

describe('writefile', function()
  before_each(clear)

  it('is working', function()
    execute('source small.vim')
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
    execute('w! test.out')
    execute('call delete(f)')
    execute('qa!')
  end)
end)
