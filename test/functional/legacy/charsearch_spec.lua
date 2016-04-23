-- Test for character searches

local helpers = require('test.functional.helpers')(after_each)
local feed, insert = helpers.feed, helpers.insert
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect

describe('charsearch', function()
  setup(clear)

  it('is working', function()
    insert([[
      Xabcdefghijkemnopqretuvwxyz
      Yabcdefghijkemnopqretuvwxyz
      Zabcdefghijkemnokqretkvwxyz]])

    -- Check that "fe" and ";" work.
    execute('/^X')
    feed('ylfep;;p,,p')
    -- Check that save/restore works.
    execute('/^Y')
    feed('ylfep')
    execute('let csave = getcharsearch()')
    feed('fip')
    execute('call setcharsearch(csave)')
    feed(';p;p')
    -- Check that setcharsearch() changes the settings.
    execute('/^Z')
    feed('ylfep')
    execute("call setcharsearch({'char': 'k'})")
    feed(';p')
    execute("call setcharsearch({'forward': 0})")
    feed('$;p')
    execute("call setcharsearch({'until': 1})")
    feed(';;p')

    -- Assert buffer contents.
    expect([[
      XabcdeXfghijkeXmnopqreXtuvwxyz
      YabcdeYfghiYjkeYmnopqreYtuvwxyz
      ZabcdeZfghijkZZemnokqretkZvwxyz]])
  end)
end)
