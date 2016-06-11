local Screen = require('test.functional.ui.screen')
local helpers = require('test.functional.helpers')(after_each)
local thelpers = require('test.functional.terminal.helpers')
local clear, eq, curbuf = helpers.clear, helpers.eq, helpers.curbuf
local feed, nvim_dir, execute = helpers.feed, helpers.nvim_dir, helpers.execute
local wait = helpers.wait
local feed_data = thelpers.feed_data

describe('terminal scrollback', function()
  local screen

  before_each(function()
    clear()
    screen = thelpers.screen_setup()
  end)

  after_each(function()
    screen:detach()
  end)

  describe('when the limit is crossed', function()
    before_each(function()
      local lines = {}
      for i = 1, 30 do
        table.insert(lines, 'line'..tostring(i))
      end
      table.insert(lines, '')
      feed_data(lines)
      screen:expect([[
        line26                                            |
        line27                                            |
        line28                                            |
        line29                                            |
        line30                                            |
        {1: }                                                 |
        -- TERMINAL --                                    |
      ]])
    end)

    it('will delete extra lines at the top', function()
      feed('<c-\\><c-n>gg')
      screen:expect([[
        ^line16                                            |
        line17                                            |
        line18                                            |
        line19                                            |
        line20                                            |
        line21                                            |
                                                          |
      ]])
    end)
  end)

  describe('with the cursor at the last row', function()
    before_each(function()
      feed_data({'line1', 'line2', 'line3', 'line4', ''})
      screen:expect([[
        tty ready                                         |
        line1                                             |
        line2                                             |
        line3                                             |
        line4                                             |
        {1: }                                                 |
        -- TERMINAL --                                    |
      ]])
    end)

    describe('and 1 line is printed', function()
      before_each(function() feed_data({'line5', ''}) end)

      it('will hide the top line', function()
        screen:expect([[
          line1                                             |
          line2                                             |
          line3                                             |
          line4                                             |
          line5                                             |
          {1: }                                                 |
          -- TERMINAL --                                    |
        ]])
        eq(7, curbuf('line_count'))
      end)

      describe('and then 3 more lines are printed', function()
        before_each(function() feed_data({'line6', 'line7', 'line8'}) end)

        it('will hide the top 4 lines', function()
          screen:expect([[
            line3                                             |
            line4                                             |
            line5                                             |
            line6                                             |
            line7                                             |
            line8{1: }                                            |
            -- TERMINAL --                                    |
          ]])

          feed('<c-\\><c-n>6k')
          screen:expect([[
            ^line2                                             |
            line3                                             |
            line4                                             |
            line5                                             |
            line6                                             |
            line7                                             |
                                                              |
          ]])

          feed('gg')
          screen:expect([[
            ^tty ready                                         |
            line1                                             |
            line2                                             |
            line3                                             |
            line4                                             |
            line5                                             |
                                                              |
          ]])

          feed('G')
          screen:expect([[
            line3                                             |
            line4                                             |
            line5                                             |
            line6                                             |
            line7                                             |
            ^line8{2: }                                            |
                                                              |
          ]])
        end)
      end)
    end)


    describe('and the height is decreased by 1', function()
      local function will_hide_top_line()
        screen:try_resize(screen._width, screen._height - 1)
        screen:expect([[
          line2                                             |
          line3                                             |
          line4                                             |
          rows: 5, cols: 50                                 |
          {1: }                                                 |
          -- TERMINAL --                                    |
        ]])
      end

      it('will hide top line', will_hide_top_line)

      describe('and then decreased by 2', function()
        before_each(function()
          will_hide_top_line()
          screen:try_resize(screen._width, screen._height - 2)
        end)

        it('will hide the top 3 lines', function()
          screen:expect([[
            rows: 5, cols: 50                                 |
            rows: 3, cols: 50                                 |
            {1: }                                                 |
            -- TERMINAL --                                    |
          ]])
          eq(8, curbuf('line_count'))
          feed('<c-\\><c-n>3k')
          screen:expect([[
            ^line4                                             |
            rows: 5, cols: 50                                 |
            rows: 3, cols: 50                                 |
                                                              |
          ]])
        end)
      end)
    end)
  end)

  describe('with empty lines after the cursor', function()
    describe('and the height is decreased by 2', function()
      before_each(function()
        screen:try_resize(screen._width, screen._height - 2)
      end)

      local function will_delete_last_two_lines()
        screen:expect([[
          tty ready                                         |
          rows: 4, cols: 50                                 |
          {1: }                                                 |
                                                            |
          -- TERMINAL --                                    |
        ]])
        eq(4, curbuf('line_count'))
      end

      it('will delete the last two empty lines', will_delete_last_two_lines)

      describe('and then decreased by 1', function()
        before_each(function()
          will_delete_last_two_lines()
          screen:try_resize(screen._width, screen._height - 1)
        end)

        it('will delete the last line and hide the first', function()
          screen:expect([[
            rows: 4, cols: 50                                 |
            rows: 3, cols: 50                                 |
            {1: }                                                 |
            -- TERMINAL --                                    |
          ]])
          eq(4, curbuf('line_count'))
          feed('<c-\\><c-n>gg')
          screen:expect([[
            ^tty ready                                         |
            rows: 4, cols: 50                                 |
            rows: 3, cols: 50                                 |
                                                              |
          ]])
          feed('a')
          screen:expect([[
            rows: 4, cols: 50                                 |
            rows: 3, cols: 50                                 |
            {1: }                                                 |
            -- TERMINAL --                                    |
          ]])
        end)
      end)
    end)
  end)

  describe('with 4 lines hidden in the scrollback', function()
    before_each(function()
      feed_data({'line1', 'line2', 'line3', 'line4', ''})
      screen:expect([[
        tty ready                                         |
        line1                                             |
        line2                                             |
        line3                                             |
        line4                                             |
        {1: }                                                 |
        -- TERMINAL --                                    |
      ]])
      screen:try_resize(screen._width, screen._height - 3)
      screen:expect([[
        line4                                             |
        rows: 3, cols: 50                                 |
        {1: }                                                 |
        -- TERMINAL --                                    |
      ]])
      eq(7, curbuf('line_count'))
    end)

    describe('and the height is increased by 1', function()
      local function pop_then_push()
        screen:try_resize(screen._width, screen._height + 1)
        screen:expect([[
          line4                                             |
          rows: 3, cols: 50                                 |
          rows: 4, cols: 50                                 |
          {1: }                                                 |
          -- TERMINAL --                                    |
        ]])
      end

      it('will pop 1 line and then push it back', pop_then_push)

      describe('and then by 3', function()
        before_each(function()
          pop_then_push()
          eq(8, curbuf('line_count'))
          screen:try_resize(screen._width, screen._height + 3)
        end)

        local function pop3_then_push1()
          screen:expect([[
            line2                                             |
            line3                                             |
            line4                                             |
            rows: 3, cols: 50                                 |
            rows: 4, cols: 50                                 |
            rows: 7, cols: 50                                 |
            {1: }                                                 |
            -- TERMINAL --                                    |
          ]])
          eq(9, curbuf('line_count'))
          feed('<c-\\><c-n>gg')
          screen:expect([[
            ^tty ready                                         |
            line1                                             |
            line2                                             |
            line3                                             |
            line4                                             |
            rows: 3, cols: 50                                 |
            rows: 4, cols: 50                                 |
                                                              |
          ]])
        end

        it('will pop 3 lines and then push one back', pop3_then_push1)

        describe('and then by 4', function()
          before_each(function()
            pop3_then_push1()
            feed('Gi')
            screen:try_resize(screen._width, screen._height + 4)
          end)

          it('will show all lines and leave a blank one at the end', function()
            screen:expect([[
              tty ready                                         |
              line1                                             |
              line2                                             |
              line3                                             |
              line4                                             |
              rows: 3, cols: 50                                 |
              rows: 4, cols: 50                                 |
              rows: 7, cols: 50                                 |
              rows: 11, cols: 50                                |
              {1: }                                                 |
                                                                |
              -- TERMINAL --                                    |
            ]])
            -- since there's an empty line after the cursor, the buffer line
            -- count equals the terminal screen height
            eq(11, curbuf('line_count'))
          end)
        end)
      end)
    end)
  end)
end)

describe('terminal prints more lines than the screen height and exits', function()
  it('will push extra lines to scrollback', function()
    clear()
    local screen = Screen.new(50, 7)
    screen:attach(false)
    execute('call termopen(["'..nvim_dir..'/tty-test", "10"]) | startinsert')
    wait()
    screen:expect([[
      line6                                             |
      line7                                             |
      line8                                             |
      line9                                             |
                                                        |
      [Process exited 0]                                |
      -- TERMINAL --                                    |
    ]])
    feed('<cr>')
    -- closes the buffer correctly after pressing a key
    screen:expect([[
      ^                                                  |
      ~                                                 |
      ~                                                 |
      ~                                                 |
      ~                                                 |
      ~                                                 |
                                                        |
    ]])
  end)
end)

