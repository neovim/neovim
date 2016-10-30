local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed, source = helpers.clear, helpers.feed, helpers.source

if helpers.pending_win32(pending) then return end

describe(':global', function()
  before_each(function()
    clear()
  end)

  it('is interrupted by mapped CTRL-C', function()
    if os.getenv("TRAVIS") and os.getenv("CLANG_SANITIZER") == "ASAN_UBSAN" then
      -- XXX: ASAN_UBSAN is too slow to react to the CTRL-C.
      pending("", function() end)
      return
    end

    source([[
      set nomore
      set undolevels=-1
      nnoremap <C-C> <NOP>
      for i in range(0, 99999)
        put ='XXX'
      endfor
      put ='ZZZ'
      1
      .delete
    ]])

    local screen = Screen.new(52, 6)
    screen:attach()
    screen:set_default_attr_ids({
      [0] = {foreground = Screen.colors.White,
             background = Screen.colors.Red},
      [1] = {bold = true,
             foreground = Screen.colors.SeaGreen}
    })

    screen:expect([[
      ^XXX                                                 |
      XXX                                                 |
      XXX                                                 |
      XXX                                                 |
      XXX                                                 |
                                                          |
    ]])

    local function test_ctrl_c(ms)
      feed(":global/^/p<CR>")
      helpers.sleep(ms)
      feed("<C-C>")
      screen:expect([[
        XXX                                                 |
        XXX                                                 |
        XXX                                                 |
        XXX                                                 |
        {0:Interrupted}                                         |
        Interrupt: {1:Press ENTER or type command to continue}^  |
      ]])
    end

    -- The test is time-sensitive. Try with different sleep values.
    local ms_values = {10, 50, 100}
    for i, ms in ipairs(ms_values) do
      if i < #ms_values then
        local status, _ = pcall(test_ctrl_c, ms)
        if status then break end
      else  -- Call the last attempt directly.
        test_ctrl_c(ms)
      end
    end
  end)
end)
