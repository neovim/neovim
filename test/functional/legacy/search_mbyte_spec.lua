local t = require('test.functional.testutil')()

local poke_eventloop = t.poke_eventloop
local clear = t.clear
local insert = t.insert
local expect = t.expect
local command = t.command

describe('search_mbyte', function()
  before_each(clear)

  it("search('multi-byte char', 'bce')", function()
    insert([=[
      Results:

      Test bce:
      Ａ]=])
    poke_eventloop()

    command('/^Test bce:/+1')
    command([[$put =search('Ａ', 'bce', line('.'))]])

    -- Assert buffer contents.
    expect([=[
      Results:

      Test bce:
      Ａ
      4]=])
  end)
end)
