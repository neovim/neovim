local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed, source = helpers.clear, helpers.feed, helpers.source
local command = helpers.command
local poke_eventloop = helpers.poke_eventloop
local sleep = helpers.sleep

describe("CTRL-C (mapped)", function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(52, 6)
    screen:attach()
  end)

  it("interrupts :global", function()
    -- Crashes luajit.
    if helpers.skip_fragile(pending) then
      return
    end

    source([[
      set nomore nohlsearch undolevels=-1
      nnoremap <C-C> <NOP>
    ]])

    command("silent edit! test/functional/fixtures/bigfile.txt")

    screen:expect([[
      ^0000;<control>;Cc;0;BN;;;;;N;NULL;;;;               |
      0001;<control>;Cc;0;BN;;;;;N;START OF HEADING;;;;   |
      0002;<control>;Cc;0;BN;;;;;N;START OF TEXT;;;;      |
      0003;<control>;Cc;0;BN;;;;;N;END OF TEXT;;;;        |
      0004;<control>;Cc;0;BN;;;;;N;END OF TRANSMISSION;;;;|
                                                          |
    ]])

    local function test_ctrl_c(ms)
      feed(":global/^/p<CR>")
      screen:sleep(ms)
      feed("<C-C>")
      screen:expect{any="Interrupt"}
    end

    -- The test is time-sensitive. Try different sleep values.
    local ms_values = {100, 1000, 10000}
    for i, ms in ipairs(ms_values) do
      if i < #ms_values then
        local status, _ = pcall(test_ctrl_c, ms)
        if status then break end
      else  -- Call the last attempt directly.
        test_ctrl_c(ms)
      end
    end
  end)

  it('interrupts :sleep', function()
    command('nnoremap <C-C> <Nop>')
    feed(':sleep 100<CR>')
    poke_eventloop()  -- wait for :sleep to start
    feed('foo<C-C>')
    poke_eventloop()  -- wait for input buffer to be flushed
    feed('i')
    screen:expect([[
      ^                                                    |
      ~                                                   |
      ~                                                   |
      ~                                                   |
      ~                                                   |
      -- INSERT --                                        |
    ]])
  end)

  it('interrupts recursive mapping', function()
    command('nnoremap <C-C> <Nop>')
    command('nmap <F2> <Ignore><F2>')
    feed('<F2>')
    sleep(10)  -- wait for the key to enter typeahead
    feed('foo<C-C>')
    poke_eventloop()  -- wait for input buffer to be flushed
    feed('i')
    screen:expect([[
      ^                                                    |
      ~                                                   |
      ~                                                   |
      ~                                                   |
      ~                                                   |
      -- INSERT --                                        |
    ]])
  end)
end)
