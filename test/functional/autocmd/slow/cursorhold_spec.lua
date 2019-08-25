local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local eval = helpers.eval
local feed = helpers.feed
local retry = helpers.retry
local source = helpers.source
local sleep = helpers.sleep

describe('CursorHoldI', function()
  before_each(clear)

  -- NOTE: since this test uses RPC it is not necessary to trigger the initial
  --       issue (#3757) via timer's or RPC callbacks in the first place.
  it('is triggered after input', function()
    source([[
    set updatetime=1

    let g:cursorhold = 0
    augroup test
      au CursorHoldI * let g:cursorhold += 1
    augroup END
    ]])
    feed('ifoo')
    retry(5, nil, function()
      sleep(1)
      eq(1, eval('g:cursorhold'))
    end)
  end)
end)
