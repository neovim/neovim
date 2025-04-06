local n = require('test.functional.testnvim')()

local poke_eventloop = n.poke_eventloop
local clear = n.clear
local insert = n.insert
local expect = n.expect
local command = n.command

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
