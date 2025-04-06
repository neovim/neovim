local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local exec = n.exec
local feed = n.feed
local async_command = n.async_meths.nvim_command
local poke_eventloop = n.poke_eventloop

describe('getchar()', function()
  before_each(clear)

  -- oldtest: Test_getchar_cursor_position()
  it('cursor positioning', function()
    local screen = Screen.new(40, 6)
    exec([[
      call setline(1, ['foobar', 'foobar', 'foobar'])
      call cursor(3, 6)
    ]])
    screen:expect([[
      foobar                                  |*2
      fooba^r                                  |
      {1:~                                       }|*2
                                              |
    ]])

    -- Default: behaves like "msg" when immediately after printing a message,
    -- even if :sleep moved cursor elsewhere.
    for _, cmd in ipairs({
      'echo 1234 | call getchar()',
      'echo 1234 | call getchar(-1, {})',
      "echo 1234 | call getchar(-1, #{cursor: 'msg'})",
      'echo 1234 | sleep 1m | call getchar()',
      'echo 1234 | sleep 1m | call getchar(-1, {})',
      "echo 1234 | sleep 1m | call getchar(-1, #{cursor: 'msg'})",
    }) do
      async_command(cmd)
      screen:expect([[
        foobar                                  |*3
        {1:~                                       }|*2
        1234^                                    |
      ]])
      feed('a')
      screen:expect([[
        foobar                                  |*2
        fooba^r                                  |
        {1:~                                       }|*2
        1234                                    |
      ]])
    end

    -- Default: behaves like "keep" when not immediately after printing a message.
    for _, cmd in ipairs({
      'call getchar()',
      'call getchar(-1, {})',
      "call getchar(-1, #{cursor: 'keep'})",
      "echo 1234 | sleep 1m | call getchar(-1, #{cursor: 'keep'})",
    }) do
      async_command(cmd)
      poke_eventloop()
      screen:expect_unchanged()
      feed('a')
      poke_eventloop()
      screen:expect_unchanged()
    end

    async_command("call getchar(-1, #{cursor: 'msg'})")
    screen:expect([[
      foobar                                  |*3
      {1:~                                       }|*2
      ^1234                                    |
    ]])
    feed('a')
    screen:expect([[
      foobar                                  |*2
      fooba^r                                  |
      {1:~                                       }|*2
      1234                                    |
    ]])

    async_command("call getchar(-1, #{cursor: 'hide'})")
    screen:expect([[
      foobar                                  |*3
      {1:~                                       }|*2
      1234                                    |
    ]])
    feed('a')
    screen:expect([[
      foobar                                  |*2
      fooba^r                                  |
      {1:~                                       }|*2
      1234                                    |
    ]])
  end)
end)
