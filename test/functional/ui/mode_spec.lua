local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear, feed, insert = n.clear, n.feed, n.insert
local command = n.command
local retry = t.retry
local api = n.api
local eq = t.eq

describe('ui mode_change event', function()
  ---@type test.functional.ui.screen
  local screen

  before_each(function()
    clear()
    screen = Screen.new(25, 4, { rgb = true })
  end)

  it('works in normal mode', function()
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*2
                               |
    ]],
      mode = 'normal',
    }

    feed('d')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*2
                               |
    ]],
      mode = 'operator',
    }

    feed('<esc>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*2
                               |
    ]],
      mode = 'normal',
    }

    n.feed(':append<cr>')
    screen:expect({ mode = 'cmdline_normal' })
    n.feed('<esc>')
    screen:expect({ mode = 'normal' })
  end)

  -- oldtest: Test_mouse_shape_after_failed_change()
  it('is restored to Normal mode after failed "c"', function()
    screen:try_resize(50, 4)
    command('set nomodifiable')

    feed('c')
    screen:expect {
      grid = [[
      ^                                                  |
      {1:~                                                 }|*2
                                                        |
    ]],
      mode = 'operator',
    }

    feed('c')
    screen:expect {
      grid = [[
      ^                                                  |
      {1:~                                                 }|*2
      {9:E21: Cannot make changes, 'modifiable' is off}     |
    ]],
      mode = 'normal',
    }
  end)

  -- oldtest: Test_mouse_shape_after_cancelling_gr()
  it('is restored to Normal mode after cancelling "gr"', function()
    feed('gr')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*2
                               |
    ]],
      mode = 'replace',
    }

    feed('<Esc>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*2
                               |
    ]],
      mode = 'normal',
    }
  end)

  -- oldtest: Test_mouse_shape_indent_norm_with_gq()
  it('is restored to Normal mode after "gq" indents using :normal #12309', function()
    screen:try_resize(60, 6)
    n.exec([[
      func Indent()
        exe "normal! \<Ignore>"
        return 0
      endfunc

      setlocal indentexpr=Indent()
      call setline(1, [repeat('a', 80), repeat('b', 80)])
    ]])

    feed('ggVG')
    screen:expect {
      grid = [[
      {17:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa}|
      {17:aaaaaaaaaaaaaaaaaaaa}                                        |
      ^b{17:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb}|
      {17:bbbbbbbbbbbbbbbbbbbb}                                        |
      {1:~                                                           }|
      {5:-- VISUAL LINE --}                                           |
    ]],
      mode = 'visual',
    }

    feed('gq')
    screen:expect {
      grid = [[
      aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      aaaaaaaaaaaaaaaaaaaa                                        |
      ^bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb|
      bbbbbbbbbbbbbbbbbbbb                                        |
      {1:~                                                           }|
                                                                  |
    ]],
      mode = 'normal',
    }
  end)

  it('works in insert mode', function()
    feed('i')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*2
      {5:-- INSERT --}             |
    ]],
      mode = 'insert',
    }

    feed('word<esc>')
    screen:expect {
      grid = [[
      wor^d                     |
      {1:~                        }|*2
                               |
    ]],
      mode = 'normal',
    }

    local matchtime = 0
    command('set showmatch')
    retry(nil, nil, function()
      matchtime = matchtime + 1
      local screen_timeout = 1000 * matchtime -- fail faster for retry.

      command('set matchtime=' .. matchtime) -- tenths of seconds
      feed('a(stuff')
      screen:expect {
        grid = [[
        word(stuff^               |
        {1:~                        }|*2
        {5:-- INSERT --}             |
      ]],
        mode = 'insert',
        timeout = screen_timeout,
      }

      feed(')')
      screen:expect {
        grid = [[
        word^(stuff)              |
        {1:~                        }|*2
        {5:-- INSERT --}             |
      ]],
        mode = 'showmatch',
        timeout = screen_timeout,
      }

      screen:expect {
        grid = [[
        word(stuff)^              |
        {1:~                        }|*2
        {5:-- INSERT --}             |
      ]],
        mode = 'insert',
        timeout = screen_timeout,
      }
    end)
  end)

  it('works in replace mode', function()
    feed('R')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*2
      {5:-- REPLACE --}            |
    ]],
      mode = 'replace',
    }

    feed('word<esc>')
    screen:expect {
      grid = [[
      wor^d                     |
      {1:~                        }|*2
                               |
    ]],
      mode = 'normal',
    }
  end)

  it('works in cmdline mode', function()
    feed(':')
    screen:expect {
      grid = [[
                               |
      {1:~                        }|*2
      :^                        |
    ]],
      mode = 'cmdline_normal',
    }

    feed('x<left>')
    screen:expect {
      grid = [[
                               |
      {1:~                        }|*2
      :^x                       |
    ]],
      mode = 'cmdline_insert',
    }

    feed('<insert>')
    screen:expect {
      grid = [[
                               |
      {1:~                        }|*2
      :^x                       |
    ]],
      mode = 'cmdline_replace',
    }

    feed('<right>')
    screen:expect {
      grid = [[
                               |
      {1:~                        }|*2
      :x^                       |
    ]],
      mode = 'cmdline_normal',
    }

    feed('<esc>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*2
                               |
    ]],
      mode = 'normal',
    }
  end)

  it('works in visual mode', function()
    insert('text')
    feed('v')
    screen:expect {
      grid = [[
      tex^t                     |
      {1:~                        }|*2
      {5:-- VISUAL --}             |
    ]],
      mode = 'visual',
    }

    feed('<esc>')
    screen:expect {
      grid = [[
      tex^t                     |
      {1:~                        }|*2
                               |
    ]],
      mode = 'normal',
    }

    command('set selection=exclusive')
    feed('v')
    screen:expect {
      grid = [[
      tex^t                     |
      {1:~                        }|*2
      {5:-- VISUAL --}             |
    ]],
      mode = 'visual_select',
    }

    feed('<esc>')
    screen:expect {
      grid = [[
      tex^t                     |
      {1:~                        }|*2
                               |
    ]],
      mode = 'normal',
    }
  end)

  describe('mouse shape modes', function()
    before_each(function()
      clear()
      screen = Screen.new(40, 8)
      api.nvim_set_option_value('mouse', 'a', {})
      api.nvim_set_option_value('mousemoveevent', true, {})
      -- Create a split to test statusline and vsep
      command('split')
      command('vsplit')
    end)

    it('sends statusline_hover mode on statusline hover with mousemev', function()
      -- Move mouse to statusline (row 3 is the statusline between splits)
      api.nvim_input_mouse('move', '', '', 0, 3, 10)
      screen:expect({
        mode = 'statusline_hover',
        condition = function()
          -- Check exact mode_stack: cursor mode (normal) then mouse mode (statusline_hover)
          eq({ 'normal', 'normal', 'statusline_hover' }, screen.mode_stack)
        end,
      })
    end)

    it('sends statusline_drag mode when dragging statusline', function()
      -- Move mouse to statusline - should trigger hover first
      api.nvim_input_mouse('move', '', '', 0, 3, 10)
      screen:expect({
        mode = 'statusline_hover',
        condition = function()
          eq({ 'normal', 'normal', 'statusline_hover' }, screen.mode_stack)
        end,
      })
      -- Start drag on statusline - should transition to drag
      api.nvim_input_mouse('left', 'press', '', 0, 3, 10)
      screen:expect({
        mode = 'statusline_drag',
        condition = function()
          eq({ 'normal', 'statusline_drag' }, screen.mode_stack)
        end,
      })
      api.nvim_input_mouse('left', 'drag', '', 0, 4, 10)
      screen:expect({
        mode = 'statusline_drag',
        condition = function()
          eq({ 'normal', 'statusline_drag' }, screen.mode_stack)
        end,
      })
      api.nvim_input_mouse('left', 'release', '', 0, 4, 10)
    end)

    it('sends vsep_hover mode on vertical separator hover with mousemev', function()
      -- Move mouse to vertical separator (column 20 is the separator)
      api.nvim_input_mouse('move', '', '', 0, 1, 20)
      screen:expect({
        mode = 'vsep_hover',
        condition = function()
          -- Check exact mode_stack: cursor mode (normal) then mouse mode (vsep_hover)
          eq({ 'normal', 'normal', 'vsep_hover' }, screen.mode_stack)
        end,
      })
    end)

    it('sends vsep_drag mode when dragging vertical separator', function()
      -- Start drag on vsep
      api.nvim_input_mouse('move', '', '', 0, 1, 20)
      screen:expect({
        mode = 'vsep_hover',
        condition = function()
          -- Check exact mode_stack: includes intermediate mode changes during drag
          eq({ 'normal', 'normal', 'vsep_hover' }, screen.mode_stack)
        end,
      })
      api.nvim_input_mouse('left', 'press', '', 0, 1, 20)
      screen:expect({
        mode = 'vsep_drag',
        condition = function()
          -- Check exact mode_stack: includes intermediate mode changes during drag
          eq({ 'normal', 'vsep_drag' }, screen.mode_stack)
        end,
      })
      api.nvim_input_mouse('left', 'drag', '', 0, 1, 25)
      screen:expect({
        mode = 'vsep_drag',
        condition = function()
          -- Check exact mode_stack: includes intermediate mode changes during drag
          eq({ 'normal', 'vsep_drag' }, screen.mode_stack)
        end,
      })
      api.nvim_input_mouse('left', 'release', '', 0, 1, 25)
    end)

    it('returns to normal mode when mouse leaves statusline', function()
      -- Move to statusline
      api.nvim_input_mouse('move', '', '', 0, 3, 10)
      screen:expect({ mode = 'statusline_hover' })
      -- Move away from statusline to normal text area
      api.nvim_input_mouse('move', '', '', 0, 1, 10)
      screen:expect({ mode = 'normal' })
    end)

    it('returns to normal mode when mouse leaves vsep', function()
      -- Move to vsep
      api.nvim_input_mouse('move', '', '', 0, 1, 20)
      screen:expect({ mode = 'vsep_hover' })
      -- Move away from vsep to normal text area
      api.nvim_input_mouse('move', '', '', 0, 1, 10)
      screen:expect({ mode = 'normal' })
    end)

    it('does not send mouse shape modes without mousemev', function()
      api.nvim_set_option_value('mousemoveevent', false, {})
      -- Move mouse to statusline
      api.nvim_input_mouse('move', '', '', 0, 3, 10)
      screen:expect({ mode = 'normal', unchanged = true })
      -- Move to vsep
      api.nvim_input_mouse('move', '', '', 0, 1, 20)
      screen:expect({ mode = 'normal', unchanged = true })
      -- Re-enable mousemoveevent to trigger mode update
      api.nvim_set_option_value('mousemoveevent', true, {})
      screen:expect({ mode = 'vsep_hover' })
    end)

    it('preserves cursor mode shape while sending mouse shape mode', function()
      -- Enter insert mode
      api.nvim_input('i')
      screen:expect({ mode = 'insert' })
      -- Move mouse to statusline while in insert mode
      api.nvim_input_mouse('move', '', '', 0, 3, 10)
      screen:expect({
        -- Should send both insert mode and statusline_hover mode
        -- The UI should receive statusline_hover for mouse cursor
        mode = 'statusline_hover',
        condition = function()
          -- Check exact mode_stack: cursor in insert, mouse in statusline_hover
          eq({ 'insert', 'statusline_hover' }, screen.mode_stack)
        end,
      })
      -- Exit insert mode and move mouse away from statusline
      api.nvim_input('<Esc>')
      api.nvim_input_mouse('move', '', '', 0, 1, 5)
      screen:expect({
        mode = 'normal',
        condition = function()
          -- Check exact mode_stack: when cursor and mouse modes are the same, only one mode is sent
          eq({ 'normal' }, screen.mode_stack)
        end,
      })
    end)
  end)
end)
