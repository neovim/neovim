-- Test for CTRL-W in Insert mode

local t = require('test.functional.testutil')()
local clear, feed, expect = t.clear, t.feed, t.expect

describe('CTRL-W in Insert mode', function()
  setup(clear)

  -- luacheck: ignore 611 (Line contains only whitespaces)
  it('works for multi-byte characters', function()
    for i = 1, 6 do
      feed('o wwwこんにちわ世界ワールドvim ' .. string.rep('<C-w>', i) .. '<esc>')
    end

    expect([[
      
       wwwこんにちわ世界ワールド
       wwwこんにちわ世界
       wwwこんにちわ
       www
       
      ]])
  end)
end)
