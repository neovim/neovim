local helpers = require('test.functional.helpers')(after_each)

local poke_eventloop = helpers.poke_eventloop
local clear = helpers.clear
local insert = helpers.insert
local expect = helpers.expect
local command = helpers.command

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
