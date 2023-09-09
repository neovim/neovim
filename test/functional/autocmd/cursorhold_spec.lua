local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local feed = helpers.feed
local retry = helpers.retry
local exec = helpers.source
local sleep = helpers.sleep
local meths = helpers.meths

before_each(clear)

describe('CursorHold', function()
  before_each(function()
    exec([[
      let g:cursorhold = 0
      augroup test
        au CursorHold * let g:cursorhold += 1
      augroup END
    ]])
  end)

  it('is triggered correctly #12587', function()
    local function test_cursorhold(fn, early)
      local ut = 2
      -- if testing with small 'updatetime' fails, double its value and test again
      retry(10, nil, function()
        ut = ut * 2
        meths.set_option_value('updatetime', ut, {})
        feed('0')  -- reset did_cursorhold
        meths.set_var('cursorhold', 0)
        sleep(ut / 4)
        fn()
        eq(0, meths.get_var('cursorhold'))
        sleep(ut / 2)
        fn()
        eq(0, meths.get_var('cursorhold'))
        sleep(ut / 2)
        eq(early, meths.get_var('cursorhold'))
        sleep(ut / 4 * 3)
        eq(1, meths.get_var('cursorhold'))
      end)
    end

    local ignore_key = meths.replace_termcodes('<Ignore>', true, true, true)
    test_cursorhold(function() end, 1)
    test_cursorhold(function() feed('') end, 1)
    test_cursorhold(function() meths.feedkeys('', 'n', true) end, 1)
    test_cursorhold(function() feed('<Ignore>') end, 0)
    test_cursorhold(function() meths.feedkeys(ignore_key, 'n', true) end, 0)
  end)

  it("reducing 'updatetime' while waiting for CursorHold #20241", function()
    meths.set_option_value('updatetime', 10000, {})
    feed('0')  -- reset did_cursorhold
    meths.set_var('cursorhold', 0)
    sleep(50)
    eq(0, meths.get_var('cursorhold'))
    meths.set_option_value('updatetime', 20, {})
    sleep(10)
    eq(1, meths.get_var('cursorhold'))
  end)
end)

describe('CursorHoldI', function()
  -- NOTE: since this test uses RPC it is not necessary to trigger the initial
  --       issue (#3757) via timer's or RPC callbacks in the first place.
  it('is triggered after input', function()
    exec([[
      set updatetime=1

      let g:cursorhold = 0
      augroup test
        au CursorHoldI * let g:cursorhold += 1
      augroup END
    ]])
    feed('ifoo')
    retry(5, nil, function()
      sleep(1)
      eq(1, meths.get_var('cursorhold'))
    end)
  end)
end)
