local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local tt = require('test.functional.testterm')

local feed, clear = n.feed, n.clear
local testprg, command = n.testprg, n.command
local eq, eval = t.eq, n.eval
local matches = t.matches
local call = n.call
local hide_cursor = tt.hide_cursor
local show_cursor = tt.show_cursor
local is_os = t.is_os
local skip = t.skip

describe(':terminal cursor', function()
  local screen

  local terminal_mode_idx ---@type number

  before_each(function()
    clear()
    screen = tt.setup_screen()

    if terminal_mode_idx == nil then
      for i, v in ipairs(screen._mode_info) do
        if v.name == 'terminal' then
          terminal_mode_idx = i
        end
      end
      assert(terminal_mode_idx)
    end
  end)

  it('moves the screen cursor when focused', function()
    tt.feed_data('testing cursor')
    screen:expect([[
      tty ready                                         |
      testing cursor^                                    |
                                                        |*4
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it('is highlighted when not focused', function()
    feed('<c-\\><c-n>')
    screen:expect([[
      tty ready                                         |
      ^                                                  |
                                                        |*5
    ]])
  end)

  describe('with number column', function()
    before_each(function()
      feed('<c-\\><c-n>:set number<cr>')
    end)

    it('is positioned correctly when unfocused', function()
      screen:expect([[
        {7:  1 }tty ready                                     |
        {7:  2 }^rows: 6, cols: 46                             |
        {7:  3 }                                              |
        {7:  4 }                                              |
        {7:  5 }                                              |
        {7:  6 }                                              |
        :set number                                       |
      ]])
    end)

    it('is positioned correctly when focused', function()
      screen:expect([[
        {7:  1 }tty ready                                     |
        {7:  2 }^rows: 6, cols: 46                             |
        {7:  3 }                                              |
        {7:  4 }                                              |
        {7:  5 }                                              |
        {7:  6 }                                              |
        :set number                                       |
      ]])
      feed('i')
      n.poke_eventloop()
      screen:expect([[
        {7:  1 }tty ready                                     |
        {7:  2 }rows: 6, cols: 46                             |
        {7:  3 }^                                              |
        {7:  4 }                                              |
        {7:  5 }                                              |
        {7:  6 }                                              |
        {3:-- TERMINAL --}                                    |
      ]])
    end)
  end)

  describe('when invisible', function()
    it('is not highlighted', function()
      skip(is_os('win'), '#31587')
      hide_cursor()
      screen:expect([[
        tty ready                                         |
                                                          |*5
        {3:-- TERMINAL --}                                    |
      ]])
      show_cursor()
      screen:expect([[
        tty ready                                         |
        ^                                                  |
                                                          |*4
        {3:-- TERMINAL --}                                    |
      ]])
      -- same for when the terminal is unfocused
      feed('<c-\\><c-n>')
      hide_cursor()
      screen:expect({
        grid = [[
        tty ready                                         |
        ^                                                  |
                                                          |*5
      ]],
        unchanged = true,
      })
      show_cursor()
      screen:expect({
        grid = [[
        tty ready                                         |
        ^                                                  |
                                                          |*5
      ]],
        unchanged = true,
      })
    end)

    it('becomes visible when exiting Terminal mode', function()
      skip(is_os('win'), '#31587')
      hide_cursor()
      screen:expect([[
        tty ready                                         |
                                                          |*5
        {3:-- TERMINAL --}                                    |
      ]])
      feed('<c-\\><c-n>')
      screen:expect([[
        tty ready                                         |
        ^                                                  |
                                                          |*5
      ]])
      feed('i')
      screen:expect([[
        tty ready                                         |
                                                          |*5
        {3:-- TERMINAL --}                                    |
      ]])

      -- Cursor is hidden; now request to show it while in a TermLeave autocmd.
      -- Process events (via :sleep) to handle the escape sequence now.
      command([[autocmd TermLeave * ++once call chansend(&channel, "\e[?25h") | sleep 1m]])
      feed([[<C-\><C-N>]]) -- Exit terminal mode; cursor should not remain hidden
      screen:expect([[
        tty ready                                         |
        ^                                                  |
                                                          |*5
      ]])

      command('bwipeout! | let chan = nvim_open_term(0, {})')
      feed('i')
      -- Hide the cursor, switch to a non-terminal buffer, then show the cursor; it shouldn't remain
      -- hidden after we're kicked out of terminal mode in the new buffer.
      -- Must ensure these actions happen within the same terminal_execute call. The stream is
      -- internal, so polling the event loop isn't necessary (terminal_receive is directly called).
      command([[call chansend(chan, "\e[?25l") | new floob | call chansend(chan, "\e[?25h")]])
      screen:expect([[
        ^                                                  |
        {4:~                                                 }|
        {5:floob                                             }|
                                                          |*2
        {18:[Scratch]                                         }|
                                                          |
      ]])

      feed('<C-W>pi')
      screen:expect([[
                                                          |
        {4:~                                                 }|
        {1:floob                                             }|
        ^                                                  |
                                                          |
        {17:[Scratch]                                         }|
        {3:-- TERMINAL --}                                    |
      ]])
    end)

    it('becomes visible on TermLeave if hidden immediately by events #32456', function()
      skip(is_os('win'), '#31587')
      -- Reproducing the issue is quite fragile; it's easiest done in a lone test case like this
      -- with no prior commands.
      feed([[<C-\><C-N>]])
      screen:expect([[
        tty ready                                         |
        ^                                                  |
                                                          |*5
      ]])

      -- Hide the cursor such that the escape sequence is processed as a side effect of showmode in
      -- terminal_enter handling events (skip_showmode -> char_avail -> vpeekc -> os_breakcheck).
      -- This requires a particular set of actions; :startinsert repros better than feed('i') here.
      hide_cursor()
      command('mode | startinsert')
      screen:expect([[
        tty ready                                         |
                                                          |*5
        {3:-- TERMINAL --}                                    |
      ]])

      feed([[<C-\><C-N>]])
      screen:expect([[
        tty ready                                         |
        ^                                                  |
                                                          |*5
      ]])
    end)
  end)

  it('can be modified by application #3681 #31685', function()
    skip(is_os('win'), '#31587')

    local states = {
      [1] = { blink = true, shape = 'block' },
      [2] = { blink = false, shape = 'block' },
      [3] = { blink = true, shape = 'horizontal' },
      [4] = { blink = false, shape = 'horizontal' },
      [5] = { blink = true, shape = 'vertical' },
      [6] = { blink = false, shape = 'vertical' },
    }

    for k, v in pairs(states) do
      tt.feed_csi(('%d q'):format(k))
      screen:expect({
        grid = [[
        tty ready                                         |
        ^                                                  |
                                                          |*4
        {3:-- TERMINAL --}                                    |
      ]],
        condition = function()
          if v.blink then
            eq(500, screen._mode_info[terminal_mode_idx].blinkon)
            eq(500, screen._mode_info[terminal_mode_idx].blinkoff)
          else
            eq(0, screen._mode_info[terminal_mode_idx].blinkon)
            eq(0, screen._mode_info[terminal_mode_idx].blinkoff)
          end

          eq(v.shape, screen._mode_info[terminal_mode_idx].cursor_shape)

          -- Cell percentages are hard coded for each shape in terminal.c
          if v.shape == 'horizontal' then
            eq(20, screen._mode_info[terminal_mode_idx].cell_percentage)
          elseif v.shape == 'vertical' then
            eq(25, screen._mode_info[terminal_mode_idx].cell_percentage)
          end
        end,
      })
    end

    feed([[<C-\><C-N>]])

    screen:expect([[
      tty ready                                         |
      ^                                                  |
                                                        |*5
    ]])

    -- Cursor returns to default on TermLeave
    eq(500, screen._mode_info[terminal_mode_idx].blinkon)
    eq(500, screen._mode_info[terminal_mode_idx].blinkoff)
    eq('block', screen._mode_info[terminal_mode_idx].cursor_shape)
  end)

  it('can be modified per terminal', function()
    skip(is_os('win'), '#31587')

    -- Set cursor to vertical bar with blink
    tt.feed_csi('5 q')
    screen:expect({
      grid = [[
      tty ready                                         |
      ^                                                  |
                                                        |*4
      {3:-- TERMINAL --}                                    |
    ]],
      condition = function()
        eq(500, screen._mode_info[terminal_mode_idx].blinkon)
        eq(500, screen._mode_info[terminal_mode_idx].blinkoff)
        eq('vertical', screen._mode_info[terminal_mode_idx].cursor_shape)
      end,
    })

    tt.hide_cursor()
    screen:expect({
      grid = [[
      tty ready                                         |
                                                        |
                                                        |*4
      {3:-- TERMINAL --}                                    |
    ]],
      condition = function()
        eq(500, screen._mode_info[terminal_mode_idx].blinkon)
        eq(500, screen._mode_info[terminal_mode_idx].blinkoff)
        eq('vertical', screen._mode_info[terminal_mode_idx].cursor_shape)
      end,
    })

    -- Exit terminal mode to reset terminal cursor settings to default and
    -- create a new terminal window
    feed([[<C-\><C-N>]])
    command('set statusline=~~~')
    command('new')
    call('jobstart', { testprg('tty-test') }, { term = true })
    feed('i')
    screen:expect({
      grid = [[
      tty ready                                         |
      ^                                                  |
      {17:~~~                                               }|
      rows: 2, cols: 50                                 |
                                                        |
      {18:~~~                                               }|
      {3:-- TERMINAL --}                                    |
    ]],
      condition = function()
        -- New terminal, cursor resets to defaults
        eq(500, screen._mode_info[terminal_mode_idx].blinkon)
        eq(500, screen._mode_info[terminal_mode_idx].blinkoff)
        eq('block', screen._mode_info[terminal_mode_idx].cursor_shape)
      end,
    })

    -- Set cursor to underline, no blink
    tt.feed_csi('4 q')
    screen:expect({
      grid = [[
      tty ready                                         |
      ^                                                  |
      {17:~~~                                               }|
      rows: 2, cols: 50                                 |
                                                        |
      {18:~~~                                               }|
      {3:-- TERMINAL --}                                    |
    ]],
      condition = function()
        eq(0, screen._mode_info[terminal_mode_idx].blinkon)
        eq(0, screen._mode_info[terminal_mode_idx].blinkoff)
        eq('horizontal', screen._mode_info[terminal_mode_idx].cursor_shape)
      end,
    })

    -- Switch back to first terminal, cursor should still be hidden
    command('wincmd p')
    screen:expect({
      grid = [[
      tty ready                                         |
                                                        |
      {18:~~~                                               }|
      rows: 2, cols: 50                                 |
                                                        |
      {17:~~~                                               }|
      {3:-- TERMINAL --}                                    |
    ]],
      condition = function()
        eq(500, screen._mode_info[terminal_mode_idx].blinkon)
        eq(500, screen._mode_info[terminal_mode_idx].blinkoff)
        eq('vertical', screen._mode_info[terminal_mode_idx].cursor_shape)
      end,
    })
  end)

  it('can be positioned arbitrarily', function()
    clear()
    screen = tt.setup_child_nvim({
      '-u',
      'NONE',
      '-i',
      'NONE',
      '--cmd',
      n.nvim_set .. ' noshowmode',
    })
    screen:expect([[
      ^                                                  |
      ~                                                 |*4
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])

    feed('i<Tab>')
    screen:expect([[
              ^                                          |
      ~                                                 |*4
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it('preserves guicursor value on TermLeave #31612', function()
    eq(3, screen._mode_info[terminal_mode_idx].hl_id)

    -- Change 'guicursor' while terminal mode is active
    command('set guicursor+=t:Error')

    local error_hl_id = call('hlID', 'Error')

    screen:expect({
      condition = function()
        eq(error_hl_id, screen._mode_info[terminal_mode_idx].hl_id)
      end,
    })

    -- Exit terminal mode
    feed([[<C-\><C-N>]])

    screen:expect([[
      tty ready                                         |
      ^                                                  |
                                                        |*5
    ]])

    eq(error_hl_id, screen._mode_info[terminal_mode_idx].hl_id)
  end)

  it('uses the correct attributes', function()
    feed([[<C-\><C-N>]])
    command([[
      bwipeout!
      let chan1 = nvim_open_term(0, {})
      vnew
      let chan2 = nvim_open_term(0, {})
    ]])
    feed('i')
    screen:expect([[
      ^                         │                        |
                               │                        |*4
      {17:[Scratch]                 }{18:[Scratch]               }|
      {3:-- TERMINAL --}                                    |
    ]])
    eq('block', screen._mode_info[terminal_mode_idx].cursor_shape)
    eq(500, screen._mode_info[terminal_mode_idx].blinkon)
    eq(500, screen._mode_info[terminal_mode_idx].blinkoff)

    -- Modify cursor in the non-current terminal; should not affect this cursor.
    command([[call chansend(chan1, "\e[4 q")]])
    screen:expect_unchanged()
    eq('block', screen._mode_info[terminal_mode_idx].cursor_shape)
    eq(500, screen._mode_info[terminal_mode_idx].blinkon)
    eq(500, screen._mode_info[terminal_mode_idx].blinkoff)

    -- Modify cursor in the current terminal.
    command([[call chansend(chan2, "\e[6 q")]])
    screen:expect_unchanged()
    eq('vertical', screen._mode_info[terminal_mode_idx].cursor_shape)
    eq(0, screen._mode_info[terminal_mode_idx].blinkon)
    eq(0, screen._mode_info[terminal_mode_idx].blinkoff)

    -- Check the cursor in the other terminal reflects our changes from before.
    command('wincmd p')
    screen:expect([[
                               │^                        |
                               │                        |*4
      {18:[Scratch]                 }{17:[Scratch]               }|
      {3:-- TERMINAL --}                                    |
    ]])
    eq('horizontal', screen._mode_info[terminal_mode_idx].cursor_shape)
    eq(0, screen._mode_info[terminal_mode_idx].blinkon)
    eq(0, screen._mode_info[terminal_mode_idx].blinkoff)
  end)
end)

describe('buffer cursor position is correct in terminal without number column', function()
  local screen

  local function setup_ex_register(str)
    screen = tt.setup_child_nvim({
      '-u',
      'NONE',
      '-i',
      'NONE',
      '-E',
      '--cmd',
      string.format('let @r = "%s"', str),
      -- <Left> and <Right> don't always work
      '--cmd',
      'cnoremap <C-X> <Left>',
      '--cmd',
      'cnoremap <C-O> <Right>',
      '--cmd',
      'set notermguicolors',
    }, {
      cols = 70,
    })
    screen:expect([[
                                                                            |*4
      Entering Ex mode.  Type "visual" to go to Normal mode.                |
      :^                                                                     |
      {3:-- TERMINAL --}                                                        |
    ]])
  end

  before_each(clear)

  describe('in a line with no multibyte chars or trailing spaces,', function()
    before_each(function()
      setup_ex_register('aaaaaaaa')
    end)

    it('at the end', function()
      feed('<C-R>r')
      screen:expect([[
                                                                              |*4
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :aaaaaaaa^                                                             |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({ 6, 9 }, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
                                                                              |*4
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :aaaaaaa^a                                                             |
                                                                              |
      ]])
      eq({ 6, 8 }, eval('nvim_win_get_cursor(0)'))
    end)

    it('near the end', function()
      feed('<C-R>r<C-X><C-X>')
      screen:expect([[
                                                                              |*4
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :aaaaaa^aa                                                             |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({ 6, 7 }, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
                                                                              |*4
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :aaaaa^aaa                                                             |
                                                                              |
      ]])
      eq({ 6, 6 }, eval('nvim_win_get_cursor(0)'))
    end)

    it('near the start', function()
      feed('<C-R>r<C-B><C-O>')
      screen:expect([[
                                                                              |*4
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :a^aaaaaaa                                                             |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({ 6, 2 }, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
                                                                              |*4
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :^aaaaaaaa                                                             |
                                                                              |
      ]])
      eq({ 6, 1 }, eval('nvim_win_get_cursor(0)'))
    end)
  end)

  describe('in a line with single-cell multibyte chars and no trailing spaces,', function()
    before_each(function()
      setup_ex_register('µµµµµµµµ')
    end)

    it('at the end', function()
      feed('<C-R>r')
      screen:expect([[
                                                                              |*4
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :µµµµµµµµ^                                                             |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({ 6, 17 }, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
                                                                              |*4
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :µµµµµµµ^µ                                                             |
                                                                              |
      ]])
      eq({ 6, 15 }, eval('nvim_win_get_cursor(0)'))
    end)

    it('near the end', function()
      feed('<C-R>r<C-X><C-X>')
      screen:expect([[
                                                                              |*4
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :µµµµµµ^µµ                                                             |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({ 6, 13 }, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
                                                                              |*4
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :µµµµµ^µµµ                                                             |
                                                                              |
      ]])
      eq({ 6, 11 }, eval('nvim_win_get_cursor(0)'))
    end)

    it('near the start', function()
      feed('<C-R>r<C-B><C-O>')
      screen:expect([[
                                                                              |*4
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :µ^µµµµµµµ                                                             |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({ 6, 3 }, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
                                                                              |*4
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :^µµµµµµµµ                                                             |
                                                                              |
      ]])
      eq({ 6, 1 }, eval('nvim_win_get_cursor(0)'))
    end)
  end)

  describe('in a line with single-cell composed multibyte chars and no trailing spaces,', function()
    before_each(function()
      setup_ex_register('µ̳µ̳µ̳µ̳µ̳µ̳µ̳µ̳')
    end)

    it('at the end', function()
      feed('<C-R>r')
      screen:expect([[
                                                                              |*4
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :µ̳µ̳µ̳µ̳µ̳µ̳µ̳µ̳^                                                             |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({ 6, 33 }, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
                                                                              |*4
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :µ̳µ̳µ̳µ̳µ̳µ̳µ̳^µ̳                                                             |
                                                                              |
      ]])
      eq({ 6, 29 }, eval('nvim_win_get_cursor(0)'))
    end)

    it('near the end', function()
      skip(is_os('win'))
      feed('<C-R>r<C-X><C-X>')
      screen:expect([[
                                                                              |*4
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :µ̳µ̳µ̳µ̳µ̳µ̳^µ̳µ̳                                                             |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({ 6, 25 }, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
                                                                              |*4
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :µ̳µ̳µ̳µ̳µ̳^µ̳µ̳µ̳                                                             |
                                                                              |
      ]])
      eq({ 6, 21 }, eval('nvim_win_get_cursor(0)'))
    end)

    it('near the start', function()
      skip(is_os('win'))
      feed('<C-R>r<C-B><C-O>')
      screen:expect([[
                                                                              |*4
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :µ̳^µ̳µ̳µ̳µ̳µ̳µ̳µ̳                                                             |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({ 6, 5 }, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
                                                                              |*4
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :^µ̳µ̳µ̳µ̳µ̳µ̳µ̳µ̳                                                             |
                                                                              |
      ]])
      eq({ 6, 1 }, eval('nvim_win_get_cursor(0)'))
    end)
  end)

  describe('in a line with double-cell multibyte chars and no trailing spaces,', function()
    before_each(function()
      setup_ex_register('哦哦哦哦哦哦哦哦')
    end)

    it('at the end', function()
      feed('<C-R>r')
      screen:expect([[
                                                                              |*4
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :哦哦哦哦哦哦哦哦^                                                     |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({ 6, 25 }, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
                                                                              |*4
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :哦哦哦哦哦哦哦^哦                                                     |
                                                                              |
      ]])
      eq({ 6, 22 }, eval('nvim_win_get_cursor(0)'))
    end)

    it('near the end', function()
      feed('<C-R>r<C-X><C-X>')
      screen:expect([[
                                                                              |*4
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :哦哦哦哦哦哦^哦哦                                                     |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({ 6, 19 }, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
                                                                              |*4
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :哦哦哦哦哦^哦哦哦                                                     |
                                                                              |
      ]])
      eq({ 6, 16 }, eval('nvim_win_get_cursor(0)'))
    end)

    it('near the start', function()
      feed('<C-R>r<C-B><C-O>')
      screen:expect([[
                                                                              |*4
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :哦^哦哦哦哦哦哦哦                                                     |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({ 6, 4 }, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
                                                                              |*4
        Entering Ex mode.  Type "visual" to go to Normal mode.                |
        :^哦哦哦哦哦哦哦哦                                                     |
                                                                              |
      ]])
      eq({ 6, 1 }, eval('nvim_win_get_cursor(0)'))
    end)
  end)

  it('at the end of a line with trailing spaces #16234', function()
    setup_ex_register('aaaaaaaa    ')
    feed('<C-R>r')
    screen:expect([[
                                                                            |*4
      Entering Ex mode.  Type "visual" to go to Normal mode.                |
      :aaaaaaaa    ^                                                         |
      {3:-- TERMINAL --}                                                        |
    ]])
    matches('^:aaaaaaaa    [ ]*$', eval('nvim_get_current_line()'))
    eq({ 6, 13 }, eval('nvim_win_get_cursor(0)'))
    feed([[<C-\><C-N>]])
    screen:expect([[
                                                                            |*4
      Entering Ex mode.  Type "visual" to go to Normal mode.                |
      :aaaaaaaa   ^                                                          |
                                                                            |
    ]])
    eq({ 6, 12 }, eval('nvim_win_get_cursor(0)'))
  end)
end)

describe('buffer cursor position is correct in terminal with number column', function()
  local screen

  local function setup_ex_register(str)
    screen = tt.setup_child_nvim({
      '-u',
      'NONE',
      '-i',
      'NONE',
      '-E',
      '--cmd',
      string.format('let @r = "%s"', str),
      -- <Left> and <Right> don't always work
      '--cmd',
      'cnoremap <C-X> <Left>',
      '--cmd',
      'cnoremap <C-O> <Right>',
      '--cmd',
      'set notermguicolors',
    }, {
      cols = 70,
    })
    screen:expect([[
      {7:  1 }                                                                  |
      {7:  2 }                                                                  |
      {7:  3 }                                                                  |
      {7:  4 }                                                                  |
      {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
      {7:  6 }:^                                                                 |
      {3:-- TERMINAL --}                                                        |
    ]])
  end

  before_each(function()
    clear()
    command('au TermOpen * set number')
  end)

  describe('in a line with no multibyte chars or trailing spaces,', function()
    before_each(function()
      setup_ex_register('aaaaaaaa')
    end)

    it('at the end', function()
      feed('<C-R>r')
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:aaaaaaaa^                                                         |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({ 6, 9 }, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:aaaaaaa^a                                                         |
                                                                              |
      ]])
      eq({ 6, 8 }, eval('nvim_win_get_cursor(0)'))
    end)

    it('near the end', function()
      feed('<C-R>r<C-X><C-X>')
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:aaaaaa^aa                                                         |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({ 6, 7 }, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:aaaaa^aaa                                                         |
                                                                              |
      ]])
      eq({ 6, 6 }, eval('nvim_win_get_cursor(0)'))
    end)

    it('near the start', function()
      feed('<C-R>r<C-B><C-O>')
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:a^aaaaaaa                                                         |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({ 6, 2 }, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:^aaaaaaaa                                                         |
                                                                              |
      ]])
      eq({ 6, 1 }, eval('nvim_win_get_cursor(0)'))
    end)
  end)

  describe('in a line with single-cell multibyte chars and no trailing spaces,', function()
    before_each(function()
      setup_ex_register('µµµµµµµµ')
    end)

    it('at the end', function()
      feed('<C-R>r')
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:µµµµµµµµ^                                                         |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({ 6, 17 }, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:µµµµµµµ^µ                                                         |
                                                                              |
      ]])
      eq({ 6, 15 }, eval('nvim_win_get_cursor(0)'))
    end)

    it('near the end', function()
      feed('<C-R>r<C-X><C-X>')
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:µµµµµµ^µµ                                                         |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({ 6, 13 }, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:µµµµµ^µµµ                                                         |
                                                                              |
      ]])
      eq({ 6, 11 }, eval('nvim_win_get_cursor(0)'))
    end)

    it('near the start', function()
      feed('<C-R>r<C-B><C-O>')
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:µ^µµµµµµµ                                                         |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({ 6, 3 }, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:^µµµµµµµµ                                                         |
                                                                              |
      ]])
      eq({ 6, 1 }, eval('nvim_win_get_cursor(0)'))
    end)
  end)

  describe('in a line with single-cell composed multibyte chars and no trailing spaces,', function()
    before_each(function()
      setup_ex_register('µ̳µ̳µ̳µ̳µ̳µ̳µ̳µ̳')
    end)

    it('at the end', function()
      feed('<C-R>r')
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:µ̳µ̳µ̳µ̳µ̳µ̳µ̳µ̳^                                                         |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({ 6, 33 }, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:µ̳µ̳µ̳µ̳µ̳µ̳µ̳^µ̳                                                         |
                                                                              |
      ]])
      eq({ 6, 29 }, eval('nvim_win_get_cursor(0)'))
    end)

    it('near the end', function()
      skip(is_os('win'))
      feed('<C-R>r<C-X><C-X>')
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:µ̳µ̳µ̳µ̳µ̳µ̳^µ̳µ̳                                                         |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({ 6, 25 }, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:µ̳µ̳µ̳µ̳µ̳^µ̳µ̳µ̳                                                         |
                                                                              |
      ]])
      eq({ 6, 21 }, eval('nvim_win_get_cursor(0)'))
    end)

    it('near the start', function()
      skip(is_os('win'))
      feed('<C-R>r<C-B><C-O>')
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:µ̳^µ̳µ̳µ̳µ̳µ̳µ̳µ̳                                                         |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({ 6, 5 }, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:^µ̳µ̳µ̳µ̳µ̳µ̳µ̳µ̳                                                         |
                                                                              |
      ]])
      eq({ 6, 1 }, eval('nvim_win_get_cursor(0)'))
    end)
  end)

  describe('in a line with double-cell multibyte chars and no trailing spaces,', function()
    before_each(function()
      setup_ex_register('哦哦哦哦哦哦哦哦')
    end)

    it('at the end', function()
      feed('<C-R>r')
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:哦哦哦哦哦哦哦哦^                                                 |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({ 6, 25 }, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:哦哦哦哦哦哦哦^哦                                                 |
                                                                              |
      ]])
      eq({ 6, 22 }, eval('nvim_win_get_cursor(0)'))
    end)

    it('near the end', function()
      feed('<C-R>r<C-X><C-X>')
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:哦哦哦哦哦哦^哦哦                                                 |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({ 6, 19 }, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:哦哦哦哦哦^哦哦哦                                                 |
                                                                              |
      ]])
      eq({ 6, 16 }, eval('nvim_win_get_cursor(0)'))
    end)

    it('near the start', function()
      feed('<C-R>r<C-B><C-O>')
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:哦^哦哦哦哦哦哦哦                                                 |
        {3:-- TERMINAL --}                                                        |
      ]])
      eq({ 6, 4 }, eval('nvim_win_get_cursor(0)'))
      feed([[<C-\><C-N>]])
      screen:expect([[
        {7:  1 }                                                                  |
        {7:  2 }                                                                  |
        {7:  3 }                                                                  |
        {7:  4 }                                                                  |
        {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
        {7:  6 }:^哦哦哦哦哦哦哦哦                                                 |
                                                                              |
      ]])
      eq({ 6, 1 }, eval('nvim_win_get_cursor(0)'))
    end)
  end)

  it('at the end of a line with trailing spaces #16234', function()
    setup_ex_register('aaaaaaaa    ')
    feed('<C-R>r')
    screen:expect([[
      {7:  1 }                                                                  |
      {7:  2 }                                                                  |
      {7:  3 }                                                                  |
      {7:  4 }                                                                  |
      {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
      {7:  6 }:aaaaaaaa    ^                                                     |
      {3:-- TERMINAL --}                                                        |
    ]])
    matches('^:aaaaaaaa    [ ]*$', eval('nvim_get_current_line()'))
    eq({ 6, 13 }, eval('nvim_win_get_cursor(0)'))
    feed([[<C-\><C-N>]])
    screen:expect([[
      {7:  1 }                                                                  |
      {7:  2 }                                                                  |
      {7:  3 }                                                                  |
      {7:  4 }                                                                  |
      {7:  5 }Entering Ex mode.  Type "visual" to go to Normal mode.            |
      {7:  6 }:aaaaaaaa   ^                                                      |
                                                                            |
    ]])
    eq({ 6, 12 }, eval('nvim_win_get_cursor(0)'))
  end)
end)
