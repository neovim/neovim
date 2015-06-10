-- Tests for :0argadd and :0argedit

local helpers = require('test.functional.helpers')
local source, clear, expect = helpers.source, helpers.clear, helpers.expect

describe('argument_0count', function()
  setup(clear)

  it('is working', function()
    source([[
      let arglists = []
      arga a b c d
      2argu
      0arga added
      call add(arglists, argv())
      2argu
      arga third
      call add(arglists, argv())
      %argd
      arga a b c d
      2argu
      0arge edited
      call add(arglists, argv())
      2argu
      arga third
      call add(arglists, argv())
      call append(0, map(copy(arglists), 'join(v:val, " ")'))
    ]])

    -- Assert buffer contents.
    expect([=[
      added a b c d
      added a third b c d
      edited a b c d
      edited a third b c d
      ]=])
  end)
end)
